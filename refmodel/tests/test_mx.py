"""M7.A tests: MX quantizers (OCP and branch recipes), INT8 quantizer, and the vectorized MX hardware model against an
independent scalar port of libgemmini. Every test asserts a nonzero count of what it checked."""
import numpy as np
import pytest
import mx
import int8
from formats import E2M1_MAGS, E4M3_MAGS
import mx_scalar_ref as ref


def same_f32(a, b):
    a, b = np.asarray(a, np.float32), np.asarray(b, np.float32)
    return a.shape == b.shape and np.array_equal(a.view(np.uint32), b.view(np.uint32))


# ------------------------------------------------------------------ quantizers
@pytest.mark.parametrize("recipe", mx.RECIPES)
@pytest.mark.parametrize("fmt", ["fp4", "fp8"])
def test_round_trip_representable(fmt, recipe):
    """Values that are exactly representable (element grid x 2^s, with the block max fixing the exponent) survive exactly."""
    grid = E2M1_MAGS if fmt == "fp4" else E4M3_MAGS
    # largest grid value that the recipe maps the block max onto: OCP -> the format max, branch -> in [1, 2]
    if recipe == "ocp":
        grid_use = grid
    else:
        grid_use = grid[grid < 2.0]
        assert grid_use.max() >= 1.0
    checked = 0
    for s in (-20, -3, 0, 5, 40):
        rows = []
        rng = np.random.default_rng(s + 100)
        for _ in range(8):
            v = rng.choice(grid_use, size=32) * rng.choice([-1, 1], size=32)
            v[rng.integers(32)] = grid_use.max()           # fix the block max
            rows.append(v * 2.0 ** s)
        x = np.array(rows)
        q = mx.quantize(x, fmt, recipe)
        assert np.array_equal(q.dequantize(), x)
        checked += x.size
    assert checked == 5 * 8 * 32


@pytest.mark.parametrize("fmt", ["fp4", "fp8"])
def test_ocp_saturation_and_scale(fmt):
    """OCP: scaled block max in [2^emax, 2^(emax+1)) saturates at the format max, and the exponent is floor(log2 amax) - emax."""
    emax = mx.EMAX_ELEM[fmt]
    fmax = 6.0 if fmt == "fp4" else 448.0
    x = np.zeros((1, 32))
    x[0, 0] = (2.0 ** (emax + 1)) * 0.999        # just under the next power of two
    x[0, 1] = -x[0, 0]
    q = mx.quantize(x, fmt, "ocp")
    assert q.exps[0, 0] == 0                     # floor(log2 amax) - emax = (emax) - emax
    d = q.dequantize()
    assert d[0, 0] == fmax and d[0, 1] == -fmax
    assert d[0, 2:].tolist() == [0.0] * 30
    # branch recipe: same input scales to [1, 2)
    qb = mx.quantize(x, fmt, "branch")
    assert qb.exps[0, 0] == emax
    assert abs(qb.dequantize()[0, 0]) <= 2.0 * 2.0 ** emax


def test_fp4_rne_ties():
    """Ties to even on the E2M1 grid (block scale pinned to 1 by a 6.0 in the block)."""
    ties = {0.25: 0.0, 0.75: 1.0, 1.25: 1.0, 1.75: 2.0, 2.5: 2.0, 3.5: 4.0, 5.0: 4.0, -0.25: 0.0, -2.5: -2.0}
    x = np.zeros((1, 32))
    x[0, 0] = 6.0
    for i, v in enumerate(ties, start=1):
        x[0, i] = v
    d = mx.quantize(x, "fp4", "ocp").dequantize()
    assert d[0, 0] == 6.0
    for i, (v, want) in enumerate(ties.items(), start=1):
        assert d[0, i] == want, (v, d[0, i], want)
    assert len(ties) == 9


def test_zero_block_and_short_k():
    for recipe in mx.RECIPES:
        for fmt in ("fp4", "fp8"):
            q = mx.quantize(np.zeros((3, 64)), fmt, recipe)
            assert q.dequantize().shape == (3, 64)
            assert not q.dequantize().any() and not np.isnan(q.dequantize()).any()
            assert (q.exps == 0).all() and (q.sc_codes == 127).all()
            qs = mx.quantize(np.arange(1, 17, dtype=float)[None, :], fmt, recipe)   # K = 16 < 32
            assert qs.dequantize().shape == (1, 16)
            assert np.abs(qs.dequantize() - np.arange(1, 17)).max() < 16     # finite, sensible


def test_exponent_clamped_to_e8m0():
    x = np.zeros((1, 32))
    x[0, 0] = 2.0 ** 200
    q = mx.quantize(x, "fp8", "ocp")
    assert q.exps[0, 0] == 127 and q.sc_codes[0, 0] == 254
    x[0, 0] = 2.0 ** -200
    q = mx.quantize(x, "fp8", "branch")
    assert q.exps[0, 0] == -127 and q.sc_codes[0, 0] == 0


def test_f_matmul_runs_and_is_close():
    rng = np.random.default_rng(1)
    a, b = rng.standard_normal((8, 64)), rng.standard_normal((64, 8))
    ref64 = a @ b
    err = {}
    for fmt in ("fp4", "fp8"):
        for recipe in mx.RECIPES:
            out = mx.fmt_matmul(a, b, fmt, recipe)
            assert out.shape == ref64.shape
            err[fmt, recipe] = np.linalg.norm(out - ref64) / np.linalg.norm(ref64)
    assert err["fp8", "ocp"] < err["fp4", "ocp"] < 0.5
    assert len(err) == 4


# ------------------------------------------------------------------ INT8
def test_int8_roundtrip_and_saturation():
    s = 0.37
    x = np.arange(-127, 128) * s
    q = int8.quantize(x)
    assert np.allclose(q.scale, s) and np.array_equal(q.q, np.arange(-127, 128))
    assert np.allclose(q.dequantize(), x, atol=1e-12, rtol=0)
    # saturation: never -128; ties to even
    q2 = int8.quantize(np.array([-3.0, 3.0, 1.0 * 3 / 127 * 0.5]))
    assert q2.q.min() == -127 and q2.q.max() == 127
    z = int8.quantize(np.zeros(5))
    assert not z.q.any() and z.scale == 1.0
    t = int8.quantize(np.array([127.0, 0.5, 1.5, 2.5, -0.5, -1.5]))        # scale 1: ties to even
    assert t.q.tolist() == [127, 0, 2, 2, 0, -2]


def test_int8_k16384_cannot_overflow():
    K = 16384
    a = np.full((2, K), 127, dtype=np.int8)
    b = np.full((K, 2), 127, dtype=np.int8)
    acc = int8.int32_matmul(a, b)
    assert acc[0, 0] == K * 127 * 127 < 2 ** 31
    a2 = np.where(np.arange(K) % 2, 127, -127).astype(np.int8)[None, :]
    assert int8.int32_matmul(a2, np.full((K, 1), 127, np.int8))[0, 0] == 0


# ------------------------------------------------------------------ primitives against the scalar port
def test_rne_fmt_vs_scalar():
    rng = np.random.default_rng(7)
    xs = np.concatenate([
        rng.standard_normal(4000).astype(np.float32) * np.float32(10.0) ** rng.integers(-8, 5, 4000).astype(np.float32),
        np.float32([0, -0.0, 247.9, 248, 252, 255.9, 256, 300, 1e-3, 2 ** -6, 2 ** -7, 2 ** -10, 2 ** -11, 1.5 * 2 ** -11, 1e-45, -1e-40]),
        (rng.integers(0, 2 ** 32, 2000, dtype=np.uint64).astype(np.uint32)).view(np.float32),
    ]).astype(np.float32)
    xs = xs[~np.isnan(xs)]
    n = 0
    for e, m in [(4, 4), (4, 5), (4, 6), (8, 7), (8, 23)]:
        got = mx.rne_fmt(xs, e, m)
        want = np.array([ref.fp_quantize_rne_scalar(v, e, m) for v in xs], dtype=np.float32)
        bad = np.flatnonzero(got.view(np.uint32) != want.view(np.uint32))
        assert bad.size == 0, (e, m, xs[bad[:4]], got[bad[:4]], want[bad[:4]])
        n += xs.size
    assert n > 30000


def test_product_trunc_vs_scalar():
    vals = np.unique(np.concatenate([mx._E4M3_F32[np.isfinite(mx._E4M3_F32)], mx._E2M1_F32]))
    prods = (vals[:, None] * vals[None, :]).ravel().astype(np.float32)
    got = mx.product_trunc(prods)
    want = np.array([ref.product_quantize_trunc(p) for p in prods], dtype=np.float32)
    assert np.array_equal(got.view(np.uint32), want.view(np.uint32))
    assert prods.size > 50000 and (got == 448).any() and (got == 0).any()


# ------------------------------------------------------------------ full Level-H model vs the scalar port
def _case(fmt, recipe, seed, M=4, N=4, K=64, dist="normal"):
    rng = np.random.default_rng(seed)
    draw = {"normal": rng.standard_normal, "laplace": lambda s: rng.laplace(size=s), "t3": lambda s: rng.standard_t(3, size=s)}[dist]
    a, b = draw((M, K)), draw((N, K))
    return mx.quantize(a, fmt, recipe), mx.quantize(b, fmt, recipe)


@pytest.mark.parametrize("fmt", ["fp4", "fp8"])
@pytest.mark.parametrize("recipe", mx.RECIPES)
@pytest.mark.parametrize("ramp,bf16", [(mx.RAMP, True), (mx.RAMP_FP32, False)])
def test_hw_matmul_vs_scalar(fmt, recipe, ramp, bf16):
    """Vectorized model == scalar libgemmini port on random matrices (incl. heavy tails; OCP recipe overflows the
    accumulator to inf/NaN, which must also match)."""
    compared = 0
    for seed, dist in enumerate(["normal", "laplace", "t3"]):
        qa, qb = _case(fmt, recipe, seed, M=3, N=3, K=96, dist=dist)
        got = mx.hw_matmul(qa, qb, ramp=ramp, bf16_acc=bf16)
        av = qa.element_values().astype(np.float32)
        bv = qb.element_values().astype(np.float32).T
        if bf16:
            want = ref.matmul(av, bv, qa.sc_codes, qb.sc_codes.T, ramp)
        else:
            want = _scalar_fp32_acc(av, bv, qa.sc_codes, qb.sc_codes.T)
        bad = np.flatnonzero(got.view(np.uint32).ravel() != want.view(np.uint32).ravel())
        eq_nan = np.isnan(got).ravel() & np.isnan(want).ravel()
        bad = [i for i in bad if not eq_nan[i]]
        assert not bad, (fmt, recipe, dist, got.ravel()[bad], want.ravel()[bad])
        compared += got.size
    assert compared == 27


def _scalar_fp32_acc(av, bv, a_sc, b_sc):
    f32 = np.float32
    M, K = av.shape
    N = bv.shape[1]
    out = np.zeros((M, N), np.float32)
    for r in range(M):
        for c in range(N):
            acc = f32(0)
            for kt in range(K // 16):
                ct = f32(0)
                for kk in range(16):
                    p = ref.product_quantize_trunc(f32(av[r, kt * 16 + kk]) * f32(bv[kt * 16 + kk, c]))
                    ct = f32(ct + p)
                g = (kt * 16) // 32
                e = int(a_sc[r, g]) + int(b_sc[g, c]) - 127
                s = ref.e8m0_decode(0 if e < 0 else (254 if e > 254 else e))
                acc = f32(acc + f32(ct * s))
            out[r, c] = acc
    return out


def test_negative_control_model_is_sensitive():
    """Changing one rounding choice in the model must change results (so the scalar comparison above can fail)."""
    qa, qb = _case("fp8", "branch", 11, M=8, N=8, K=256)
    base = mx.hw_matmul(qa, qb)
    wide = mx.hw_matmul(qa, qb, ramp=[(8, 7)] * 16)          # no reduced-precision ramp
    assert (base.view(np.uint32) != wide.view(np.uint32)).sum() > 0
    f32acc = mx.hw_matmul(qa, qb, ramp=mx.RAMP_FP32, bf16_acc=False)
    assert (base.view(np.uint32) != f32acc.view(np.uint32)).sum() > 0
    # product truncation to RNE would also change things
    orig = mx.product_trunc
    try:
        mx.product_trunc = lambda x: np.asarray(x, np.float32)      # no truncation
        mx._LUT_CACHE.clear()
        nt = mx.hw_matmul(qa, qb)
    finally:
        mx.product_trunc = orig
        mx._LUT_CACHE.clear()
    assert (base.view(np.uint32) != nt.view(np.uint32)).sum() > 0
