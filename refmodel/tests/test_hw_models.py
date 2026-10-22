"""M7.A tests for refmodel/hw_models.py: the exact float32 fma, the FP32/NVFP4/INT8 Level-H models, controls."""
from fractions import Fraction
import math
import numpy as np
import pytest
import hw_models as hm
import mx


def round_f32_exact(v: Fraction) -> np.float32:
    """Round an exact rational to float32 (RNE), independent of numpy/hardware float behaviour."""
    if v == 0:
        return np.float32(0)
    s = -1 if v < 0 else 1
    v = abs(v)
    e = math.floor(math.log2(v)) if v >= 1 else -math.ceil(math.log2(1 / v))
    while Fraction(2) ** e > v:
        e -= 1
    while Fraction(2) ** (e + 1) <= v:
        e += 1
    e = max(e, -126)
    q = Fraction(2) ** (e - 23)
    n = v / q
    fl = n.numerator // n.denominator
    rem = n - fl
    if rem > Fraction(1, 2) or (rem == Fraction(1, 2) and fl % 2):
        fl += 1
    return np.float32(s * float(fl * q))


def test_fma32_matches_exact_rational():
    rng = np.random.default_rng(3)
    n = 6000
    a = (rng.standard_normal(n) * 10.0 ** rng.integers(-6, 6, n)).astype(np.float32)
    b = (rng.standard_normal(n) * 10.0 ** rng.integers(-6, 6, n)).astype(np.float32)
    c = (rng.standard_normal(n) * 10.0 ** rng.integers(-6, 6, n)).astype(np.float32)
    # adversarial: c cancels the product to within a few ulp, and products that land exactly on a float32 midpoint
    c[:2000] = (-(a[:2000].astype(np.float64) * b[:2000])).astype(np.float32) * np.float32(1 + 2.0 ** -20)
    k = np.arange(2000, 3000)
    a[k] = np.float32(1 + 2.0 ** -12)
    b[k] = np.float32(1 + 2.0 ** -12)                        # product 1 + 2^-11 + 2^-24: a float32 tie plus a bit
    c[k] = np.float32(2.0 ** -24) * rng.choice([-1, 0, 1], size=k.size).astype(np.float32)
    got = hm.fma32(a, b, c)
    want = np.array([round_f32_exact(Fraction(float(x)) * Fraction(float(y)) + Fraction(float(z))) for x, y, z in zip(a, b, c)], dtype=np.float32)
    assert np.array_equal(got.view(np.uint32), want.view(np.uint32))
    assert n == 6000 and got.size == 6000


def test_fp32_models_basic_and_distinct():
    rng = np.random.default_rng(5)
    a, b = rng.standard_normal((16, 256)), rng.standard_normal((256, 16))
    ref = a @ b
    for f in (hm.fp32_h, hm.fp32_fused_h):
        out = f(a, b)
        assert out.shape == ref.shape
        assert np.linalg.norm(out - ref) / np.linalg.norm(ref) < 1e-5
    # the two PE styles differ in some outputs (fused vs separate rounding), otherwise the distinction would be vacuous
    d = (hm.fp32_h(a, b) != hm.fp32_fused_h(a, b)).sum()
    assert d > 0
    # exactness on integer-valued data: both are exact
    ai, bi = rng.integers(-8, 8, (8, 64)), rng.integers(-8, 8, (64, 8))
    assert np.array_equal(hm.fp32_h(ai, bi), ai @ bi) and np.array_equal(hm.fp32_fused_h(ai, bi), ai @ bi)


def test_control_no_quantization_is_exact():
    """Metric control: the unquantized path has error exactly 0 and SQNR inf (accuracy_sweep imports the same metrics)."""
    import accuracy_sweep as sw
    rng = np.random.default_rng(1)
    a, b = rng.standard_normal((8, 32)), rng.standard_normal((32, 8))
    ref = a @ b
    m = sw.metrics(a @ b, ref)
    assert m["n_compared"] == 64 and m["max_abs"] == 0 and m["rel_fro"] == 0 and math.isinf(m["sqnr_db"]) and abs(m["cosine"] - 1.0) < 1e-12
    with pytest.raises(ValueError):
        sw.metrics(np.zeros((0, 0)), np.zeros((0, 0)))


def test_nvfp4_h_matches_float32_model_and_ablation_differs():
    rng = np.random.default_rng(2)
    a, b = rng.standard_normal((32, 512)), rng.standard_normal((512, 32))
    h = hm.nvfp4_h(a, b)
    f = hm.nvfp4_f(a, b)
    assert np.linalg.norm(h - f) / np.linalg.norm(f) < 1e-5            # float32 block scaling only
    bf = hm.nvfp4_bf16acc(a, b)
    assert (bf != h).sum() > 0 and np.isfinite(bf).all()


def test_registry_complete():
    assert set(hm.LEVEL_F) >= {"fp32", "int8", "mxfp8_ocp", "mxfp4_ocp", "nvfp4"}
    assert set(hm.LEVEL_H) >= {"fp32", "int8", "mxfp8_branch", "mxfp4_branch", "nvfp4", "nvfp4_bf16acc", "mxfp4_branch_fp32acc"}
    rng = np.random.default_rng(0)
    a, b = rng.standard_normal((16, 64)), rng.standard_normal((64, 16))
    for table in (hm.LEVEL_F, hm.LEVEL_H):
        for name, fn in table.items():
            out = fn(a, b)
            assert out.shape == (16, 16), name
            if "ocp" not in name or table is hm.LEVEL_F:
                assert np.isfinite(out).all(), name
