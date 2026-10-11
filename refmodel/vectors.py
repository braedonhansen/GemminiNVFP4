"""Export test vectors for the Chisel testbenches into refmodel/vectors/."""
import json
import struct
import sys
from pathlib import Path
import numpy as np
from formats import e4m3_decode
from quant import quantize, NVFP4Tensor
from hw_dot import code_to_int, hw_matmul, block_sums

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

    (out / "e4m3_table.json").write_text(json.dumps(
        [None if np.isnan(v) else float(v) for v in e4m3_decode(np.arange(256))]))
    return pairs, blocks


if __name__ == "__main__":
    p, b = export(sys.argv[1] if len(sys.argv) > 1 else OUT)
    print(f"wrote {len(p)} pair vectors and {len(b)} block vectors")
