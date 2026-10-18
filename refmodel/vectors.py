"""Export test vectors for the Chisel testbenches into refmodel/vectors/."""
import json
import struct
import sys
from pathlib import Path
import numpy as np
from formats import e4m3_decode
from quant import quantize, NVFP4Tensor
from hw_dot import code_to_int, hw_matmul, block_sums, mesh_block_sums

OUT = Path(__file__).parent / "vectors"


def f32_bits(x):
    return struct.unpack("<I", struct.pack("<f", np.float32(x)))[0]


def pair_vectors():
    """All 256 (a, b) E2M1 code pairs with the exact doubled-integer product."""
    rows = []
    for a in range(16):
        for b in range(16):
            prod = int(code_to_int(a)) * int(code_to_int(b))  # 4x the real product
            rows.append({"a": a, "b": b, "product": prod, "product_9bit": prod & 0x1FF})
    return rows


def block_row(a_codes, b_codes, sa, sb, ta, tb):
    qa = NVFP4Tensor(np.array([a_codes], np.uint8), np.array([[sa]], np.uint8), np.array([ta], np.float32), 16)
    qb = NVFP4Tensor(np.array([b_codes], np.uint8), np.array([[sb]], np.uint8), np.array([tb], np.float32), 16)
    isum = int(block_sums(qa, qb)[0, 0, 0])
    res = np.float32(hw_matmul(qa, qb)[0, 0])  # float64 math, rounded once to FP32
    return {
        "a_codes": [int(c) for c in a_codes],
        "b_codes": [int(c) for c in b_codes],
        "a_scale": int(sa), "b_scale": int(sb),
        "a_tensor_scale": float(ta), "b_tensor_scale": float(tb),
        "a_tensor_scale_bits": f32_bits(ta), "b_tensor_scale_bits": f32_bits(tb),
        "int_sum": isum, "int_sum_13bit": isum & 0x1FFF,
        "result": float(res), "result_bits": f32_bits(res),
    }


def block_vectors(n=64, seed=1):
    rng = np.random.default_rng(seed)
    rows = []
    # Random blocks: rows with varied magnitude so scale bytes differ.
    mags = 10.0 ** rng.uniform(-2, 1, (n, 1))
    qa = quantize(rng.standard_normal((n, 16)) * mags)
    qb = quantize(rng.standard_normal((n, 16)) * mags[::-1])
    for i in range(n):
        rows.append(block_row(qa.codes[i], qb.codes[i], qa.scales[i, 0], qb.scales[i, 0],
                              qa.tensor_scale[0], qb.tensor_scale[0]))
    # Corner cases: worst-case positive/negative sums and all zeros.
    one = 0x38  # E4M3 1.0
    rows.append(block_row([7] * 16, [7] * 16, one, one, 1.0, 1.0))
    rows.append(block_row([7] * 16, [15] * 16, one, one, 1.0, 1.0))
    rows.append(block_row([0] * 16, [7] * 16, one, one, 1.0, 1.0))
    return rows


def _pass(name, a, b):
    """One mesh pass: A (M,K) codes, B (K,N) codes, C = exact integer block sums."""
    a, b = np.asarray(a, np.uint8), np.asarray(b, np.uint8)
    return {"name": name, "A": a, "B": b, "C": mesh_block_sums(a, b)}


def mesh_pass_vectors(dim=16, n_random=24, seed=7):
    """Weight-stationary mesh passes for a dim x dim array holding 2 E2M1 values per PE input.

    One pass = one K block of length K = dim:  A is M x K and B is K x N with M = N = 2*dim
    (two M rows share a pair on each mesh row, two N columns share a pair on each mesh column).
    dim=16 passes: refmodel's 67 block vectors (every block sits on the diagonal of some pass),
    corner passes (+-2304 extremes, zeros, alternating signs) and random passes.
    """
    m = n = 2 * dim
    rng = np.random.default_rng(seed)
    passes = []
    if dim == 16:
        blocks = block_vectors()
        nb = len(blocks)  # 67
        for p in range(-(-nb // m)):
            ia = [(m * p + i) % nb for i in range(m)]
            a = np.array([blocks[i]["a_codes"] for i in ia], np.uint8)          # (M, 16)
            b = np.array([blocks[i]["b_codes"] for i in ia], np.uint8).T        # (16, N)
            ps = _pass(f"refblocks{p}", a, b)
            ps["diag_blocks"] = [(i, blocks[ia[i]]["int_sum"]) for i in range(m) if m * p + i < nb]
            passes.append(ps)
    full = lambda c, r, cc: np.full((r, cc), c, np.uint8)
    k = dim
    passes += [
        _pass("max_pos", full(7, m, k), full(7, k, n)),        # +6 * +6 doubled = +12*12 -> +144 each, x16 = +2304
        _pass("max_neg", full(7, m, k), full(15, k, n)),       # -2304
        _pass("neg_neg", full(15, m, k), full(15, k, n)),      # +2304
        _pass("zeros", full(0, m, k), full(0, k, n)),
        _pass("neg_zero", full(8, m, k), full(15, k, n)),      # -0 operands -> 0
    ]
    alt_k = np.tile(np.where(np.arange(k) % 2 == 0, 7, 15).astype(np.uint8), (m, 1))
    passes.append(_pass("alt_k", alt_k, full(7, k, n)))        # +144,-144,... -> 0
    sign_m = np.tile(np.where(np.arange(m) % 2 == 0, 7, 15).astype(np.uint8)[:, None], (1, k))
    sign_n = np.tile(np.where(np.arange(n) % 2 == 0, 7, 15).astype(np.uint8)[None, :], (k, 1))
    passes.append(_pass("checker", sign_m, sign_n))            # +-2304 checkerboard
    for i in range(n_random):
        passes.append(_pass(f"rand{i}", rng.integers(0, 16, (m, k)), rng.integers(0, 16, (k, n))))
    return passes


def write_mesh_passes(path, passes):
    """Text format (easy to parse from Scala): 'PASS name M K N', M lines of A, K lines of B, M lines of C."""
    lines = []
    for p in passes:
        mm, kk = p["A"].shape
        nn = p["B"].shape[1]
        lines.append(f"PASS {p['name']} {mm} {kk} {nn}")
        for mat in (p["A"], p["B"], p["C"]):
            lines += [" ".join(str(int(x)) for x in row) for row in mat]
    Path(path).write_text("\n".join(lines) + "\n")


def export(out=OUT):
    out = Path(out)
    out.mkdir(parents=True, exist_ok=True)
    pairs = pair_vectors()
    (out / "e2m1_pairs.json").write_text(json.dumps(pairs, indent=1))
    # index = a*16 + b, one 9-bit two's complement product per line
    (out / "e2m1_pairs.hex").write_text("".join(f"{r['product_9bit']:03x}\n" for r in pairs))

    blocks = block_vectors()
    (out / "blocks.json").write_text(json.dumps(blocks, indent=1))
    # a_codes b_codes a_scale b_scale a_ts b_ts int_sum(13b) result(fp32) ; codes packed with element 0 in the low nibble
    pack = lambda cs: "".join(f"{c:x}" for c in reversed(cs))
    lines = [
        f"{pack(r['a_codes'])} {pack(r['b_codes'])} {r['a_scale']:02x} {r['b_scale']:02x} "
        f"{r['a_tensor_scale_bits']:08x} {r['b_tensor_scale_bits']:08x} {r['int_sum_13bit']:04x} {r['result_bits']:08x}\n"
        for r in blocks
    ]
    (out / "blocks.hex").write_text("".join(lines))

    write_mesh_passes(out / "mesh_passes_d16.txt", mesh_pass_vectors(16))
    write_mesh_passes(out / "mesh_passes_d4.txt", mesh_pass_vectors(4, n_random=200, seed=11))

    (out / "e4m3_table.json").write_text(json.dumps(
        [None if np.isnan(v) else float(v) for v in e4m3_decode(np.arange(256))]))
    return pairs, blocks


if __name__ == "__main__":
    p, b = export(sys.argv[1] if len(sys.argv) > 1 else OUT)
    print(f"wrote {len(p)} pair vectors and {len(b)} block vectors")
