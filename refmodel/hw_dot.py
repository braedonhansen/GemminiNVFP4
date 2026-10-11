"""Hardware-style NVFP4 dot product, plus INT8 and FP32 paths for comparison."""
import numpy as np
from formats import e4m3_decode
from quant import quantize, BLOCK

INT2 = np.array([0, 1, 2, 3, 4, 6, 8, 12], dtype=np.int32)  # E2M1 magnitude * 2
ACC_BITS = 13
ACC_MIN, ACC_MAX = -(1 << (ACC_BITS - 1)), (1 << (ACC_BITS - 1)) - 1


def code_to_int(codes):
    """4-bit E2M1 code -> signed doubled integer."""
    codes = np.asarray(codes)
    mag = INT2[codes & 7]
    return np.where(codes & 8, -mag, mag).astype(np.int32)


def check_acc(sums):
    assert sums.min() >= ACC_MIN and sums.max() <= ACC_MAX, "block sum overflows 13-bit accumulator"


def block_sums(qa, qb):
    """Exact integer sum of each 16-element block. Returns (M, N, nblocks)."""
    ia = code_to_int(qa.codes).reshape(qa.codes.shape[0], -1, BLOCK)
    ib = code_to_int(qb.codes).reshape(qb.codes.shape[0], -1, BLOCK)
    sums = np.einsum("mbk,nbk->mnb", ia, ib)
    check_acc(sums)
    return sums


def hw_matmul(qa, qb):
    """qa: (M, K), qb: (N, K) (B transposed). Returns (M, N) float64.

    Integer block sums first; scales applied after: sum * sA*sB * tA*tB / 4.
    """
    sums = block_sums(qa, qb)
    sa = e4m3_decode(qa.scales)[:, None, :]
    sb = e4m3_decode(qb.scales)[None, :, :]
    acc = (sums * (sa * sb)).sum(axis=-1)
    ts = qa.tensor_scale.astype(np.float64)[:, None] * qb.tensor_scale.astype(np.float64)[None, :]
    return acc * ts / 4


def dequant_matmul(qa, qb):
    """Dequantize every value first, then multiply in float64."""
    return qa.dequantize() @ qb.dequantize().T


def hw_dot(a, b):
    """Quantize two vectors and return (result, int block sums)."""
    qa, qb = quantize(a), quantize(b)
    return float(hw_matmul(qa, qb)[0, 0]), block_sums(qa, qb)[0, 0]


def dequant_dot(a, b):
    return float(dequant_matmul(quantize(a), quantize(b))[0, 0])


def int8_dot(a, b):
    """Symmetric per-tensor INT8: int32 accumulate, one FP scale at the end."""
    a, b = np.asarray(a, np.float64), np.asarray(b, np.float64)
    sa, sb = np.abs(a).max() / 127, np.abs(b).max() / 127
    qa = np.clip(np.rint(a / sa), -127, 127).astype(np.int32)
    qb = np.clip(np.rint(b / sb), -127, 127).astype(np.int32)
    return float(int(np.dot(qa, qb)) * sa * sb)


def fp32_dot(a, b):
    """Sequential FP32 multiply-accumulate."""
    acc = np.float32(0)
    for x, y in zip(np.asarray(a, np.float32), np.asarray(b, np.float32)):
        acc = np.float32(acc + np.float32(x * y))
    return float(acc)


def four_ways(a, b):
    exact = float(np.dot(np.asarray(a, np.float64), np.asarray(b, np.float64)))
    hw, sums = hw_dot(a, b)
    return {
        "exact": exact,
        "fp32": fp32_dot(a, b),
        "int8": int8_dot(a, b),
        "nvfp4_hw": hw,
        "nvfp4_dequant": dequant_dot(a, b),
        "int_sum": int(sums[0]),
    }


if __name__ == "__main__":
    rng = np.random.default_rng(0)
    a = rng.standard_normal(16).astype(np.float32)
    b = rng.standard_normal(16).astype(np.float32)
    r = four_ways(a, b)
    for name in ("exact", "fp32", "int8", "nvfp4_hw", "nvfp4_dequant"):
        print(f"{name:14s} {r[name]:.8f}  err {abs(r[name] - r['exact']):.3g}")
    print("integer block sum:", r["int_sum"])
    print("hw - dequant:", r["nvfp4_hw"] - r["nvfp4_dequant"])
