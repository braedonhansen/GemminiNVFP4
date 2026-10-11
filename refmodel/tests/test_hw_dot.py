from fractions import Fraction
import numpy as np
import pytest
from formats import e4m3_decode, e2m1_decode
from quant import quantize, NVFP4Tensor
from hw_dot import (code_to_int, hw_matmul, dequant_matmul, block_sums, hw_dot, check_acc,
                    four_ways, int8_dot, fp32_dot, INT2)


def vec(seed, n=16):
    return np.random.default_rng(seed).standard_normal(n).astype(np.float32)


def mk(codes, scale=0x38):
    codes = np.array([codes], np.uint8)
    return NVFP4Tensor(codes, np.full((1, codes.shape[1] // 16), scale, np.uint8), np.ones(1, np.float32), codes.shape[1])


def test_int_table():
    assert INT2.tolist() == [0, 1, 2, 3, 4, 6, 8, 12]


@pytest.mark.parametrize("code", range(16))
def test_code_to_int_is_double_of_value(code):
    assert code_to_int(code) == 2 * e2m1_decode(code)


def exact_dequant_first(qa, qb):
    """Exact rational dot product of the dequantized values."""
    tot = Fraction(0)
    ta, tb = Fraction(float(qa.tensor_scale[0])), Fraction(float(qb.tensor_scale[0]))
    for i in range(qa.codes.shape[1]):
        sa = Fraction(float(e4m3_decode(qa.scales[0, i // 16])))
        sb = Fraction(float(e4m3_decode(qb.scales[0, i // 16])))
        va = Fraction(float(e2m1_decode(qa.codes[0, i]))) * sa * ta
        vb = Fraction(float(e2m1_decode(qb.codes[0, i]))) * sb * tb
        tot += va * vb
    return tot


def exact_hw(qa, qb):
    tot = Fraction(0)
    sums = block_sums(qa, qb)
    for b in range(qa.scales.shape[1]):
        tot += int(sums[0, 0, b]) * Fraction(float(e4m3_decode(qa.scales[0, b]))) * Fraction(float(e4m3_decode(qb.scales[0, b])))
    return tot * Fraction(float(qa.tensor_scale[0])) * Fraction(float(qb.tensor_scale[0])) / 4


@pytest.mark.parametrize("seed", range(20))
def test_hw_equals_dequant_first_exactly_in_rational_arithmetic(seed):
    qa, qb = quantize(vec(seed, 48)), quantize(vec(seed + 100, 48))
    assert exact_hw(qa, qb) - exact_dequant_first(qa, qb) == 0


def test_hw_vs_dequant_first_fp32_nearly_always_identical():
    # Mathematically identical (see the rational test), but the two float64 evaluation
    # orders can differ by ~1e-16, which flips the FP32 rounding in a ~1% of cases.
    mism = 0
    for seed in range(300):
        qa, qb = quantize(vec(seed)), quantize(vec(seed + 1000))
        h = np.float32(hw_matmul(qa, qb)[0, 0])
        d = np.float32(dequant_matmul(qa, qb)[0, 0])
        # a dot that cancels to exactly 0 in hw can leave ~1e-16 residue in dequant-first
        assert abs(h - d) <= max(np.spacing(abs(d)), 1e-12)
        mism += h != d
    assert mism <= 10


def test_hw_vs_dequant_float64_within_rounding():
    for seed in range(100):
        qa, qb = quantize(vec(seed)), quantize(vec(seed + 7))
        h, d = hw_matmul(qa, qb)[0, 0], dequant_matmul(qa, qb)[0, 0]
        assert abs(h - d) <= 1e-14 * max(abs(d), 1e-3)


def test_hw_matmul_matches_dequant_matmul_shapes():
    rng = np.random.default_rng(3)
    a, b = rng.standard_normal((5, 40)), rng.standard_normal((7, 40))
    qa, qb = quantize(a), quantize(b)
    h, d = hw_matmul(qa, qb), dequant_matmul(qa, qb)
    assert h.shape == (5, 7) and np.allclose(h, d, rtol=1e-12, atol=1e-12)


def test_power_of_two_scales_exact_in_float64():
    # scales are all exactly 1.0, so every operation is exact in float64
    q = mk([7, 15, 6, 14, 5, 13, 4, 12] * 2)
    assert hw_matmul(q, q)[0, 0] == dequant_matmul(q, q)[0, 0]


def test_worst_case_sum_is_2304_and_fits_13_bits():
    q = mk([7] * 16)
    assert block_sums(q, q)[0, 0, 0] == 16 * 12 * 12 == 2304
    assert -(1 << 12) <= 2304 < (1 << 12)
    assert block_sums(q, mk([15] * 16))[0, 0, 0] == -2304


def test_random_block_sums_within_13_bits():
    rng = np.random.default_rng(0)
    a, b = quantize(rng.standard_normal((200, 16))), quantize(rng.standard_normal((200, 16)))
    s = block_sums(a, b)
    assert s.min() >= -4096 and s.max() <= 4095


def test_accumulator_bound_assertion_fires():
    with pytest.raises(AssertionError):
        check_acc(np.array([4096]))
    with pytest.raises(AssertionError):
        check_acc(np.array([-4097]))
    check_acc(np.array([4095, -4096]))


def test_known_integer_sum():
    a = mk([7, 6, 5, 4] + [0] * 12)    # doubled ints 12, 8, 6, 4
    b = mk([1, 2, 3, 15] + [0] * 12)   # doubled ints 1, 2, 3, -12
    assert block_sums(a, b)[0, 0, 0] == 12 * 1 + 8 * 2 + 6 * 3 + 4 * -12
    assert hw_matmul(a, b)[0, 0] == (12 + 16 + 18 - 48) / 4


def test_multi_block_dot_applies_per_block_scales():
    a, b = vec(1, 32), vec(2, 32)
    qa, qb = quantize(a), quantize(b)
    assert block_sums(qa, qb).shape == (1, 1, 2)
    assert abs(hw_dot(a, b)[0] - float(a.astype(float) @ b.astype(float))) < 3


def test_int8_exact_on_grid_and_close_otherwise():
    a = np.array([127, -127, 64, 0], float)
    assert int8_dot(a, a) == float(a @ a)
    x, y = vec(0), vec(1)
    assert abs(int8_dot(x, y) - float(x.astype(float) @ y.astype(float))) < 0.2


def test_fp32_dot_close():
    x, y = vec(0), vec(1)
    assert abs(fp32_dot(x, y) - float(x.astype(float) @ y.astype(float))) < 1e-5


def test_four_ways_ordering():
    r = four_ways(vec(0), vec(1))
    e = lambda k: abs(r[k] - r["exact"])
    assert e("fp32") < e("int8") < e("nvfp4_hw")
    assert abs(r["int_sum"]) <= 2304
