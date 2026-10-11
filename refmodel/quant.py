"""NVFP4 quantize / dequantize. Blocks of 16 along the last (reduction) axis."""
from dataclasses import dataclass
import numpy as np
from formats import e2m1_encode, e2m1_decode, e4m3_encode_up, e4m3_decode

BLOCK = 16


@dataclass
class NVFP4Tensor:
    codes: np.ndarray         # (rows, nblocks*16) uint8, 4-bit E2M1 codes
    scales: np.ndarray        # (rows, nblocks) uint8, E4M3 block scales
    tensor_scale: np.ndarray  # float32, shape (1,) or (rows,)
    k: int                    # original (unpadded) length of the last axis

    def dequantize(self):
        vals = e2m1_decode(self.codes).reshape(*self.scales.shape, BLOCK)
        vals = vals * e4m3_decode(self.scales)[..., None]
        vals = vals.reshape(self.codes.shape) * self.tensor_scale.astype(np.float64)[:, None]
        return vals[:, : self.k]


def quantize(x):
    x = np.atleast_2d(np.asarray(x, dtype=np.float64))
    rows, k = x.shape
    nb = -(-k // BLOCK)
    padded = np.zeros((rows, nb * BLOCK))
    padded[:, :k] = x
    blocks = padded.reshape(rows, nb, BLOCK)

    amax_t = np.abs(x).max() if x.size else 0.0
    ts = np.float32(amax_t / (6 * 448)) if amax_t > 0 else np.float32(1.0)
    while float(ts) * 6 * 448 < amax_t:  # float32 rounding must not push scales past 448
        ts = np.nextafter(ts, np.float32(np.inf))
    ts64 = float(ts)

    amax_b = np.abs(blocks).max(axis=-1)
    sc = e4m3_encode_up(amax_b / 6 / ts64)
    # Guard against float division error: need 6*scale*ts >= amax exactly.
    while True:
        bad = (6 * e4m3_decode(sc) * ts64 < amax_b) & (sc < 126)
        if not bad.any():
            break
        sc = sc + bad.astype(np.uint8)

    denom = (e4m3_decode(sc) * ts64)[..., None]
    y = np.divide(blocks, denom, out=np.zeros_like(blocks), where=denom > 0)
    codes = e2m1_encode(y).reshape(rows, nb * BLOCK)
    return NVFP4Tensor(codes, sc.astype(np.uint8), np.array([ts], dtype=np.float32), k)


def concat_rows(parts):
    """Stack separately quantized tensors (each with its own tensor scale), e.g. a KV cache."""
    return NVFP4Tensor(
        np.concatenate([p.codes for p in parts]),
        np.concatenate([p.scales for p in parts]),
        np.concatenate([np.repeat(p.tensor_scale, p.codes.shape[0]) for p in parts]),
        parts[0].k,
    )
