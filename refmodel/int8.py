"""INT8 (stock Gemmini default) quantizer and exact INT32 matmul.

Recipe (M7.A): per-tensor symmetric, scale = amax / 127, round-to-nearest-even, clamp to [-127, 127].
Hardware (Level H): the PE multiplies INT8 x INT8 and the accumulator adds into INT32 exactly, so the result is the
exact integer sum. K = 16384 cannot overflow: 16384 * 127 * 127 = 264,241,… < 2^31 (checked below, not assumed).
The stock design's output requantization (acc_scale at mvout) is a separate step and is not part of this model; the
Spike checks read the accumulator at full width, as M4's hw/tests/nvfp4_v0 does.
"""
from dataclasses import dataclass
import numpy as np

QMAX = 127


@dataclass
class Int8Tensor:
    q: np.ndarray      # int8, same shape as the input
    scale: float       # float64, x ~ q * scale

    def dequantize(self):
        return self.q.astype(np.float64) * self.scale


def quantize(x):
    x = np.asarray(x, dtype=np.float64)
    amax = float(np.abs(x).max()) if x.size else 0.0
    scale = amax / QMAX if amax > 0 else 1.0
    q = np.clip(np.rint(x / scale), -QMAX, QMAX).astype(np.int8)
    return Int8Tensor(q, scale)


def int32_matmul(qa, qb):
    """qa: (M, K) int8, qb: (K, N) int8 -> exact (M, N) int32 (computed in int64, range-checked)."""
    acc = np.asarray(qa, dtype=np.int64) @ np.asarray(qb, dtype=np.int64)
    bound = qa.shape[1] * QMAX * QMAX
    assert bound < 2 ** 31, "K too large for INT32 accumulation"
    assert acc.size and np.abs(acc).max() <= bound
    return acc.astype(np.int32)


def hw_matmul(a, b):
    """Level H: quantize a (M, K) and b (K, N), exact INT32 accumulation, dequantize in float64."""
    qa, qb = quantize(a), quantize(b)
    return int32_matmul(qa.q, qb.q).astype(np.float64) * (qa.scale * qb.scale)


def fmt_matmul(a, b):
    """Level F: quantize, dequantize, float64 matmul."""
    return quantize(a).dequantize() @ quantize(b).dequantize()
