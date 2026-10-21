"""Export the M6.3C end-to-end RTL test case (hw/tests/nvfp4_e2e.c): M = N = 32, K = 64, NVFP4, hardware operand layouts.

Writes hw/tests/nvfp4_e2e_data.h with
  A_in_hw[M/2][K]  : byte [r][k] = code(row 2r+1, k) << 4 | code(row 2r, k)         (the MX FP4 quad activation layout)
  B_in[K][N/2]     : byte [k][c] = code(k, col 2c+1) << 4 | code(k, col 2c)
  A_sc[K/16][M]    : E4M3 block-scale codes, A_sc[kb][m]   (MX_LOAD_SCALES act, linear)
  B_sc[K/16][N]    : E4M3 block-scale codes, B_sc[kb][n]   (MX_LOAD_SCALES wgt, linear)
  tA, tB           : tensor scales (float32)
  out_bits[M][N]   : expected float32 output bits, refmodel hw_matmul_v0 order:
                     blk = (float(isum) * sA) * sB; acc = acc + blk (kb ascending, from +0); out = acc * ((tA*tB)*0.25f)
A few scale codes are forced to 0 / subnormal so zero blocks, -0 first blocks (isum < 0, zero scale) and subnormal scales occur.
"""
import struct
import sys
from pathlib import Path
import numpy as np
from quant import quantize, BLOCK
from hw_dot import hw_matmul_v0, block_sums

M, K, N = 32, 64, 32      # default shape (M6.3C); export(path, seed, m, n, k) takes any M, N multiple of 32 and K multiple of 16
SEED = 20261018


def make_case(seed=SEED, M=M, N=N, K=K):
    assert M % 32 == 0 and N % 32 == 0 and K % BLOCK == 0, "M, N must be multiples of 32 (quad tiles), K of 16"
    rng = np.random.default_rng(seed)
    nb = K // BLOCK

    def gen(rows):
        x = rng.standard_normal((rows, nb, BLOCK)) * 2.0 ** rng.integers(-3, 4, size=(rows, nb, 1))
        return x.reshape(rows, K)

    qa, qb = quantize(gen(M)), quantize(gen(N))
    # corner scale codes (E4M3 code 0 = zero, 1..7 = subnormal); the model decodes whatever codes it is given.
    # The same pattern is repeated in every 32-row / 32-column tile (offset 32*t), block indices wrap modulo K/16;
    # for the default 32x32x64 case this is exactly the original six assignments.
    for t in range(M // 32):
        o = 32 * t
        qa.scales[o + 3, :] = 0x00          # one row per tile, every block: zero scale -> every block is +-0 (isum < 0 gives -0)
        qa.scales[o + 7, 2 % nb] = 0x03     # subnormal
        qa.scales[o + 20, 1 % nb] = 0x00
    for t in range(N // 32):
        o = 32 * t
        qb.scales[o + 5, 0] = 0x00          # column 5 of the tile, block 0
        qb.scales[o + 11, 3 % nb] = 0x07
        qb.scales[o + 30, 1 % nb] = 0x01
    if (M, N, K) != (32, 32, 64):
        # multi-tile / long-K cases: random data rarely keeps the sign negative over ALL blocks, so force outputs that
        # are -0 without the "+0 + blk" first write: zero-scale A row 32t+3 holds -1.0 (code 0xA), B column 32u+13 holds
        # +1.0 (code 0x2) -> every block sum is negative, every block is -0, the unfixed datapath would give -0.
        for t in range(M // 32):
            qa.codes[32 * t + 3, :] = 0xA
        for u in range(N // 32):
            qb.codes[32 * u + 13, :] = 0x2
    return qa, qb


def f32_bits(x):
    return struct.unpack("<I", struct.pack("<f", float(np.float32(x))))[0]


def _fmt(vals, per_line, fn):
    vals = list(vals)
    return "\n".join("    " + ", ".join(fn(v) for v in vals[i:i + per_line]) + "," for i in range(0, len(vals), per_line))


def build(seed=SEED, M=M, N=N, K=K):
    qa, qb = make_case(seed, M, N, K)
    sums, out = hw_matmul_v0(qa, qb)
    ca, cb = qa.codes.astype(np.uint8), qb.codes.astype(np.uint8)   # (M, K), (N, K)
    a_hw = ((ca[1::2, :] << 4) | ca[0::2, :]).astype(np.uint8)       # [M/2][K]
    b_hw = ((cb[1::2, :].T << 4) | cb[0::2, :].T).astype(np.uint8)   # [K][N/2]
    a_sc = qa.scales.T.astype(np.uint8)                              # [K/16][M]
    b_sc = qb.scales.T.astype(np.uint8)                              # [K/16][N]
    return qa, qb, sums, out, a_hw, b_hw, a_sc, b_sc


def export(path, seed=SEED, M=M, N=N, K=K):
    qa, qb, sums, out, a_hw, b_hw, a_sc, b_sc = build(seed, M, N, K)
    from formats import e4m3_decode
    sa0 = e4m3_decode(qa.scales[:, 0]).astype(np.float32)
    sb0 = e4m3_decode(qb.scales[:, 0]).astype(np.float32)
    blk0 = (sums[:, :, 0].astype(np.float32) * sa0[:, None]) * sb0[None, :]
    neg0 = int(np.sum((blk0 == 0) & np.signbit(blk0)))
    # what a datapath that stores the first block directly (no +0 + blk) would produce: count the outputs whose bits differ
    sa = e4m3_decode(qa.scales).astype(np.float32)
    sb = e4m3_decode(qb.scales).astype(np.float32)
    acc = None
    for kb in range(sums.shape[2]):
        blk = (sums[:, :, kb].astype(np.float32) * sa[:, None, kb]) * sb[None, :, kb]
        acc = blk if acc is None else (acc + blk).astype(np.float32)
    ts = (qa.tensor_scale[0] * qb.tensor_scale[0]) * np.float32(0.25)
    unfixed = (acc * np.float32(ts)).astype(np.float32)
    sens = int(np.sum(unfixed.view(np.uint32) != out.view(np.uint32)))
    ts_a, ts_b = float(qa.tensor_scale[0]), float(qb.tensor_scale[0])
    fac = (np.float32(qa.tensor_scale[0]) * np.float32(qb.tensor_scale[0])) * np.float32(0.25)
    lines = [
        "// Generated by refmodel/export_e2e.py. Do not edit.",
        f"// NVFP4 end-to-end case: A {M}x{K} times B {K}x{N}, 16-element blocks along K, seed {seed}.",
        f"// first-block -0 values in the model: {neg0} (outputs that would differ without the +0 + blk first write: {sens}); scale factor (tA*tB)*0.25f = {float(fac).hex()}",
        "#ifndef NVFP4_E2E_DATA_H", "#define NVFP4_E2E_DATA_H", "#include <stdint.h>",
        f"#define E2E_M {M}", f"#define E2E_K {K}", f"#define E2E_N {N}",
        f"static const uint8_t A_in_hw[{M // 2}][{K}] = {{",
        _fmt(a_hw.ravel(), 16, lambda v: f"0x{int(v):02x}"), "};",
        f"static const uint8_t B_in[{K}][{N // 2}] = {{",
        _fmt(b_hw.ravel(), 16, lambda v: f"0x{int(v):02x}"), "};",
        f"static const uint8_t A_sc[{K // BLOCK}][{M}] = {{",
        _fmt(a_sc.ravel(), 16, lambda v: f"0x{int(v):02x}"), "};",
        f"static const uint8_t B_sc[{K // BLOCK}][{N}] = {{",
        _fmt(b_sc.ravel(), 16, lambda v: f"0x{int(v):02x}"), "};",
        f"static const float tA = {ts_a.hex()}f;", f"static const float tB = {ts_b.hex()}f;",
        f"static const uint32_t out_bits[{M}][{N}] = {{",
        _fmt(out.ravel(), 8, lambda v: f"0x{f32_bits(v):08x}u"), "};",
        "#endif", "",
    ]
    Path(path).write_text("\n".join(lines), newline="\n")
    if (M, N, K) != (32, 32, 64):
        assert sens > 0, "case has no output sensitive to the -0 fix"
    print(f"wrote {path} (M={M} N={N} K={K} seed={seed}): first-block -0 count {neg0}, outputs sensitive to the -0 fix {sens}, {int(np.sum(out == 0))} zero outputs, "
          f"out range [{out.min():.4g}, {out.max():.4g}], factor {float(fac):.6g}")


if __name__ == "__main__":
    # usage: export_e2e.py [path [seed [M N K]]]
    a = sys.argv
    shape = tuple(int(v) for v in a[3:6]) if len(a) >= 6 else (M, N, K)
    export(a[1] if len(a) > 1 else "hw/tests/nvfp4_e2e_data.h", int(a[2]) if len(a) > 2 else SEED, *shape)
