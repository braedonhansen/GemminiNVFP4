"""Level-H (hardware) matmul models and Level-F (format) matmul models for the M7.A accuracy study.

Every function takes A (M, K) and B (K, N) as float64 and returns the (M, N) result as float64.
Level F: quantize, dequantize, multiply in float64.        Level H: the design's own arithmetic.

Which Level-H models are proven bit-exact against Spike (see docs/M7-accuracy-results.md and logs/m7a.steps):
  nvfp4_h      hw_matmul_v0 (float32 block scaling, exact integer block sums)
  int8_h       exact INT32 accumulation
  fp32_h       stock FP32 mesh as modelled by libgemmini: results += a*b (separate multiply and add), DIM=4 tiles
  mxfp8_h / mxfp4_h   refmodel/mx.py hw_matmul (branch recipe)
Models that are software ablations or that Spike cannot judge are named accordingly (nvfp4_bf16acc, mxfp4_fp32acc,
fp32_fused_h, *_ocp_h).
"""
import numpy as np
import int8
import mx
import quant
from hw_dot import hw_matmul_v0, dequant_matmul

F32 = np.float32


# ----------------------------------------------------------------------------- exact float32 fused multiply-add
def fma32(a, b, c):
    """Correctly rounded float32 fma(a, b, c), elementwise: the float64 product is exact, TwoSum gives the exact
    float64 sum error, and the single rounding to float32 breaks the one case (an exact float32 midpoint) where
    rounding the float64 sum would double-round. Validated against C fmaf in refmodel/tests/test_hw_models.py."""
    a64, b64, c64 = (np.asarray(v, np.float32).astype(np.float64) for v in (a, b, c))
    p = a64 * b64                                  # exact: 24 + 24 bits < 53
    s = p + c64
    bb = s - p
    e = (p - (s - bb)) + (c64 - bb)                # Knuth TwoSum error: p + c = s + e exactly
    r = s.astype(np.float32)
    t = s - r.astype(np.float64)                   # distance from s to r (exact)
    half_ulp = np.where(t > 0, np.nextafter(r, np.float32(np.inf)).astype(np.float64) - r.astype(np.float64),
                        r.astype(np.float64) - np.nextafter(r, np.float32(-np.inf)).astype(np.float64)) / 2
    on_mid = np.isfinite(s) & (t != 0) & (np.abs(t) == half_ulp) & (e != 0)
    away = on_mid & (np.sign(e) == np.sign(t))      # true value is past the midpoint, so round to the other neighbour
    other = np.where(t > 0, np.nextafter(r, np.float32(np.inf)), np.nextafter(r, np.float32(-np.inf)))
    return np.where(away, other, r).astype(np.float32)


# ----------------------------------------------------------------------------- FP32 (stock FPGemminiRocketConfig, DIM = 4)
FP32_DIM = 4


def fp32_h(a, b, dim=FP32_DIM):
    """libgemmini's WS model: per K tile of `dim`: results = 0; results += a_k * b_k for k ascending (two roundings each),
    then accumulator += results (first tile overwrites). All float32."""
    a32, b32 = np.asarray(a, F32), np.asarray(b, F32)
    M, K = a32.shape
    N = b32.shape[1]
    assert K % dim == 0
    acc = None
    for kt in range(K // dim):
        r = np.zeros((M, N), F32)
        for kk in range(dim):
            k = kt * dim + kk
            r = (r + (a32[:, k, None] * b32[None, k, :]).astype(F32)).astype(F32)
        acc = r if acc is None else (acc + r).astype(F32)
    return acc.astype(np.float64)


def fp32_fused_h(a, b, dim=FP32_DIM):
    """The PE as written in Arithmetic.scala (MulAddRecFN: one rounding per multiply-add, partial sum entering from the
    row above), k ascending down the column; accumulator adds are exact-then-round float32 adds. Not checked against
    RTL (no Verilator in M7.A); differs from fp32_h only in the multiply-add rounding."""
    a32, b32 = np.asarray(a, F32), np.asarray(b, F32)
    M, K = a32.shape
    N = b32.shape[1]
    assert K % dim == 0
    acc = None
    for kt in range(K // dim):
        r = np.zeros((M, N), F32)
        for kk in range(dim):
            k = kt * dim + kk
            r = fma32(np.broadcast_to(a32[:, k, None], (M, N)), np.broadcast_to(b32[None, k, :], (M, N)), r)
        acc = r if acc is None else (acc + r).astype(F32)
    return acc.astype(np.float64)


def fp32_f(a, b):
    return np.asarray(a, F32).astype(np.float64) @ np.asarray(b, F32).astype(np.float64)


# ----------------------------------------------------------------------------- NVFP4
def _nv_quant(a, b):
    return quant.quantize(a), quant.quantize(np.asarray(b).T)


def nvfp4_f(a, b):
    qa, qb = _nv_quant(a, b)
    return dequant_matmul(qa, qb)


def nvfp4_h(a, b):
    qa, qb = _nv_quant(a, b)
    return hw_matmul_v0(qa, qb)[1].astype(np.float64)


def nvfp4_bf16acc(a, b):
    """Software ablation: NVFP4 with the FP32 block accumulator replaced by BF16 (RNE to BF16 after each block add);
    exact integer block sums and the float32 block scaling are unchanged, the tensor-scale multiply stays float32."""
    qa, qb = _nv_quant(a, b)
    assert qa.tensor_scale.shape == (1,)
    from hw_dot import block_sums
    from formats import e4m3_decode
    sums = block_sums(qa, qb)
    sa = e4m3_decode(qa.scales).astype(F32)
    sb = e4m3_decode(qb.scales).astype(F32)
    acc = np.zeros(sums.shape[:2], F32)
    for kb in range(sums.shape[2]):
        blk = ((sums[:, :, kb].astype(F32) * sa[:, None, kb]) * sb[None, :, kb]).astype(F32)
        acc = mx.bf16_round((acc + blk).astype(F32))
    ts = (qa.tensor_scale[0] * qb.tensor_scale[0]) * F32(0.25)
    return (acc * F32(ts)).astype(np.float64)


# ----------------------------------------------------------------------------- MX
def mx_f(fmt, recipe):
    return lambda a, b: mx.fmt_matmul(a, b, fmt, recipe)


def mx_h(fmt, recipe, ramp=mx.RAMP, bf16_acc=True):
    def f(a, b):
        qa, qb = mx.quantize(a, fmt, recipe), mx.quantize(np.asarray(b).T, fmt, recipe)
        return mx.hw_matmul(qa, qb, ramp=ramp, bf16_acc=bf16_acc).astype(np.float64)
    return f


# ----------------------------------------------------------------------------- registries
LEVEL_F = {
    "fp32": fp32_f,
    "int8": int8.fmt_matmul,
    "mxfp8_ocp": mx_f("fp8", "ocp"),
    "mxfp4_ocp": mx_f("fp4", "ocp"),
    "mxfp8_branch": mx_f("fp8", "branch"),
    "mxfp4_branch": mx_f("fp4", "branch"),
    "nvfp4": nvfp4_f,
}

LEVEL_H = {
    "fp32": fp32_h,
    "int8": int8.hw_matmul,
    "mxfp8_branch": mx_h("fp8", "branch"),
    "mxfp4_branch": mx_h("fp4", "branch"),
    "nvfp4": nvfp4_h,
    # software ablations (not hardware)
    "nvfp4_bf16acc": nvfp4_bf16acc,
    "mxfp4_branch_fp32acc": mx_h("fp4", "branch", ramp=mx.RAMP_FP32, bf16_acc=False),
    # FP32 with a fused multiply-add PE: unverified against RTL
    "fp32_fused": fp32_fused_h,
    # OCP-recipe data on the MX hardware: expected to overflow the (4,4) accumulator (reported as a finding)
    "mxfp8_ocp": mx_h("fp8", "ocp"),
    "mxfp4_ocp": mx_h("fp4", "ocp"),
}
