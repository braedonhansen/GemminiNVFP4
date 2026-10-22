"""MX (microscaling) block quantizers and a bit-exact numpy model of the Berkeley MX Gemmini arithmetic.

Credit: the hardware arithmetic modelled here (product truncation, per-lane accumulator precision ramp, BF16
cross-tile accumulation) is a port of the behaviour of libgemmini's `mx_loop_ws_spad` and `mx_fp_math.h`
(ucb-bar/gemmini branch gemmini-mx-cleanup @ 266c593f, libgemmini 87663107), BSD 3-Clause, (c) The Regents of the
University of California. The Python models in that repo (fp4_matmul_model.py, fp8_matmul_model.py) describe the same
arithmetic. This file is an independent vectorized numpy implementation; Spike is the judge of bit-exactness (see
refmodel/tests/test_mx.py for a scalar port used as an extra check, and hw/tests/mx_acc.c for the Spike harness).

Two quantization recipes (block size 32 along K, shared power-of-two scale, elements RNE with saturation):
  "ocp"    OCP MX v1.0: shared exponent = floor(log2(block amax)) - emax_elem  (E2M1: 2, E4M3: 8).
  "branch" the recipe behind the MX branch's committed test data (MXQuant "e2e" convention):
           shared exponent = floor(log2(block amax)), so scaled block maxima land in [1, 2].
The branch recipe was inferred from its headers (see docs/M7-accuracy-results.md); the OCP recipe puts block maxima at
256..448 (E4M3) which overflows the (4,4) in-array accumulator (it holds < 2^8).
"""
from dataclasses import dataclass
import numpy as np
from formats import e2m1_encode, e2m1_decode, e4m3_encode, e4m3_decode, E4M3_VALUES, E2M1_MAGS

BLOCK = 32
EMAX_ELEM = {"fp4": 2, "fp8": 8}
RECIPES = ("ocp", "branch")
TILE = 16                                    # K per array pass (DIM)
RAMP = [(4, 4)] * 8 + [(4, 5)] * 2 + [(4, 6)] * 5 + [(8, 7)]   # (exp bits, mantissa bits) of accumulator lane kk (DIM=16)
RAMP_FP32 = [(8, 23)] * 16                   # ablation: no rounding in the array
PROD_FRAC_BITS = 3                           # products are truncated (RTZ) to 1.fff
PROD_MAX = 448.0                             # mx_product_saturate with (4,3): +-448
PROD_FLUSH_EXP = -16                         # products below 2^-16 flush to zero


# ----------------------------------------------------------------------------- quantizers

@dataclass
class MXTensor:
    fmt: str               # "fp4" or "fp8"
    recipe: str
    codes: np.ndarray      # (rows, nblocks*BLOCK) uint8 element codes (E2M1 nibble or E4M3 byte)
    exps: np.ndarray       # (rows, nblocks) int16 unbiased shared exponents; E8M0 code = exps + 127
    k: int                 # unpadded length of the last axis

    @property
    def sc_codes(self):
        return (self.exps + 127).astype(np.uint8)

    def element_values(self):
        c = self.codes
        return e2m1_decode(c) if self.fmt == "fp4" else e4m3_decode(c)

    def dequantize(self):
        v = self.element_values().reshape(*self.exps.shape, BLOCK)
        v = v * np.ldexp(1.0, self.exps.astype(np.int32))[..., None]
        return v.reshape(self.codes.shape)[:, : self.k]


def shared_exponent(amax, fmt, recipe):
    """Unbiased shared exponent per block; a zero block gets 0 (its elements are all zero anyway)."""
    amax = np.asarray(amax, dtype=np.float64)
    _, e = np.frexp(amax)                    # amax = m * 2^e, m in [0.5, 1)  ->  floor(log2) = e - 1
    fl = np.where(amax > 0, e - 1, 0)
    if recipe == "ocp":
        fl = np.where(amax > 0, fl - EMAX_ELEM[fmt], 0)
    elif recipe != "branch":
        raise ValueError(recipe)
    return np.clip(fl, -127, 127).astype(np.int16)


def quantize(x, fmt, recipe):
    """Quantize rows of x (rows, K) along K in blocks of 32 (a short last block is zero-padded)."""
    assert fmt in EMAX_ELEM and recipe in RECIPES
    x = np.atleast_2d(np.asarray(x, dtype=np.float64))
    rows, k = x.shape
    nb = -(-k // BLOCK)
    padded = np.zeros((rows, nb * BLOCK))
    padded[:, :k] = x
    blocks = padded.reshape(rows, nb, BLOCK)
    exps = shared_exponent(np.abs(blocks).max(axis=-1), fmt, recipe)
    y = np.ldexp(blocks, -exps.astype(np.int32)[..., None])      # exact power-of-two scaling
    codes = (e2m1_encode(y) if fmt == "fp4" else e4m3_encode(y)).reshape(rows, nb * BLOCK)
    return MXTensor(fmt, recipe, codes, exps, k)


def fmt_matmul(a, b, fmt, recipe):
    """Level F: quantize A (M, K) and B (K, N) along K, dequantize, float64 matmul."""
    return quantize(a, fmt, recipe).dequantize() @ quantize(np.asarray(b).T, fmt, recipe).dequantize().T


# ----------------------------------------------------------------------------- arithmetic primitives (float32, exact IEEE)

def rne_fmt(x, e_bits, m_bits):
    """libgemmini fp_quantize_rne_scalar, vectorized. x float32 -> float32 on the (e_bits, m_bits) grid, RNE.
    Underflow to zero returns +0 (sign dropped), overflow returns +-inf, NaN/inf pass through."""
    x = np.asarray(x, dtype=np.float32)
    if (e_bits, m_bits) == (8, 23):
        return x + np.float32(0)      # identity (and -0 -> +0, like every other grid)
    bias = (1 << (e_bits - 1)) - 1
    emin, emax = 1 - bias, bias
    ax = np.abs(x)
    drop = 23 - m_bits
    bits = ax.view(np.uint32)
    lsb = (bits >> np.uint32(drop)) & np.uint32(1)
    rounded = (((bits + np.uint32((1 << (drop - 1)) - 1) + lsb) >> np.uint32(drop)) << np.uint32(drop)).view(np.float32)
    quantum = 2.0 ** (emin - m_bits)
    sub = (np.rint(ax.astype(np.float64) / quantum) * quantum).astype(np.float32)
    res = np.where(ax < np.float32(2.0 ** emin), sub, rounded)
    res = np.where(res.astype(np.float64) >= 2.0 ** (emax + 1), np.float32(np.inf), res)
    out = np.where((x < 0) & (res != 0), -res, res)
    return np.where(np.isfinite(x), out, x).astype(np.float32)


def bf16_round(x):
    return rne_fmt(x, 8, 7)


def bf16_add(x, y):
    """libgemmini bf16_accum_add(x, y) for x, y already BF16 values."""
    return rne_fmt(np.asarray(x, np.float32) + np.asarray(y, np.float32), 8, 7)


def product_trunc(x):
    """mx_product_quantize_trunc(x, 4, 3): truncate (RTZ) to 3 fractional bits, flush < 2^-16, saturate at +-448."""
    x = np.asarray(x, dtype=np.float32)
    fin = np.isfinite(x) & (x != 0)
    m, e = np.frexp(np.where(fin, x, np.float32(1)))
    E = e - 1
    frac = 2.0 * np.abs(m).astype(np.float64) - 1.0
    val = np.ldexp(1.0 + np.floor(frac * (1 << PROD_FRAC_BITS)) / (1 << PROD_FRAC_BITS), E)
    val = np.where(x < 0, -val, val)
    val = np.where(np.abs(val) > PROD_MAX, np.sign(val) * PROD_MAX, val)
    out = np.where(fin & (E >= PROD_FLUSH_EXP), val, 0.0).astype(np.float32)
    return np.where(np.isfinite(x), out, x)   # non-finite inputs pass through (the saturating quantizers never produce them)


_E4M3_F32 = E4M3_VALUES.astype(np.float32)
_E2M1_F32 = np.concatenate([E2M1_MAGS, -E2M1_MAGS]).astype(np.float32)   # index = 4-bit code (sign bit = bit 3)
_LUT_CACHE = {}


def _prod_luts(fmt, ramp):
    """Per-ramp-class lookup tables: table[(code_a << nbits) | code_b] = rne(product_trunc(a*b), ae, am)."""
    key = (fmt, tuple(sorted(set(ramp))))
    if key not in _LUT_CACHE:
        vals = _E2M1_F32 if fmt == "fp4" else _E4M3_F32
        p = product_trunc(vals[:, None] * vals[None, :]).ravel()
        _LUT_CACHE[key] = {cls: rne_fmt(p, *cls) for cls in set(ramp)}
    return _LUT_CACHE[key]


def e8m0_scale(sa, sb):
    """Scale 2^(code - 127) with code = clamp(sa + sb - 127, 0, 254), as float32 (exact; 2^-127 is a float32 subnormal)."""
    code = np.clip(np.asarray(sa, np.int32) + np.asarray(sb, np.int32) - 127, 0, 254)
    return np.ldexp(np.float64(1.0), code - 127).astype(np.float32)


# ----------------------------------------------------------------------------- Level H: the MX array + BF16 accumulation

def hw_matmul(qa, qb, ramp=RAMP, bf16_acc=True, return_bits=False):
    """Bit-exact model of one `gemmini_loop_ws_spad` MX matmul (E4M3 x E4M3 single, or FP4 x FP4 quad).

    qa: MXTensor (M, K), qb: MXTensor (N, K) (B transposed). K is a multiple of 16.
    Order of operations, as in libgemmini (mx_loop_ws_spad):
      for each K tile of 16 (ascending):  Ct = 0
        for kk in 0..15:  p = product_trunc(a*b); Ct = rne_{ramp[kk]}( Ct + rne_{ramp[kk]}(p) )
        scaled = bf16(Ct * 2^(sa+sb-127-127))      (one E8M0 scale per 32 K, i.e. per two tiles)
        C = bf16( bf16(C) + bf16(scaled) )          (C starts at 0)
    (libgemmini also re-rounds Ct to the lane's format before adding; the ramp only ever widens, so that is the identity.)
    With bf16_acc=False and ramp=RAMP_FP32 the same loop runs entirely in float32 (software ablation).
    Returns float32 (M, N) (BF16 values when bf16_acc), or also the BF16 bit patterns.
    """
    assert qa.fmt == qb.fmt and qa.k == qb.k
    M, N, K = qa.codes.shape[0], qb.codes.shape[0], qa.k
    assert K % TILE == 0
    luts = _prod_luts(qa.fmt, ramp)
    shift = np.uint32(4 if qa.fmt == "fp4" else 8)
    ia = qa.codes.astype(np.uint32)[:, :K]
    ib = qb.codes.astype(np.uint32)[:, :K]
    acc = np.zeros((M, N), dtype=np.float32)
    err = np.errstate(invalid="ignore", over="ignore")       # inf/NaN from accumulator overflow are results, not errors
    err.__enter__()
    for kt in range(K // TILE):
        ct = np.zeros((M, N), dtype=np.float32)
        for kk in range(TILE):
            k = kt * TILE + kk
            idx = (ia[:, k, None] << shift) | ib[None, :, k]
            cls = ramp[kk]
            ct = rne_fmt(ct + luts[cls][idx], *cls)
        g = (kt * TILE) // BLOCK
        s = e8m0_scale(qa.sc_codes[:, g][:, None], qb.sc_codes[:, g][None, :])
        scaled = (ct * s).astype(np.float32)
        if bf16_acc:
            acc = bf16_add(acc, bf16_round(scaled))
        else:
            acc = (acc + scaled).astype(np.float32)
    err.__exit__(None, None, None)
    if return_bits:
        return acc, bf16_bits(acc)
    return acc


def bf16_bits(x):
    """float32 (BF16-valued) -> uint16 bit pattern; +-0 -> 0 (as f32_to_bf16_rne canonicalizes zero)."""
    x = np.asarray(x, dtype=np.float32)
    b = (x.view(np.uint32) >> np.uint32(16)).astype(np.uint16)
    return np.where(x == 0, np.uint16(0), b)
