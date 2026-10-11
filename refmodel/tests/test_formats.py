import numpy as np
import pytest
from formats import (E2M1_MAGS, E4M3_VALUES, e2m1_encode, e2m1_decode,
                     e4m3_encode, e4m3_encode_up, e4m3_decode)


@pytest.mark.parametrize("code", range(16))
def test_e2m1_decode_table(code):
    expect = E2M1_MAGS[code & 7] * (-1 if code & 8 else 1)
    assert e2m1_decode(code) == expect


def test_e2m1_roundtrip_exhaustive():
    codes = np.arange(16, dtype=np.uint8)
    assert (e2m1_encode(e2m1_decode(codes)) == codes).all()


@pytest.mark.parametrize("x,mag_code", [
    (0.25, 0),   # tie 0 / 0.5 -> even (0)
    (0.75, 2),   # tie 0.5 / 1 -> 1
    (1.25, 2),   # tie 1 / 1.5 -> 1
    (1.75, 4),   # tie 1.5 / 2 -> 2
    (2.5, 4),    # tie 2 / 3 -> 2
    (3.5, 6),    # tie 3 / 4 -> 4
    (5.0, 6),    # tie 4 / 6 -> 4
])
def test_e2m1_rne_ties(x, mag_code):
    assert e2m1_encode(x) == mag_code
    assert e2m1_encode(-x) == mag_code | 8


def test_e2m1_non_ties_round_to_nearest():
    assert e2m1_encode(0.2) == 0 and e2m1_encode(0.3) == 1
    assert e2m1_encode(5.1) == 7 and e2m1_encode(4.9) == 6


def test_e2m1_saturates_at_6():
    assert e2m1_decode(e2m1_encode([6.1, 100.0, 1e30, np.inf])).tolist() == [6.0] * 4
    assert e2m1_decode(e2m1_encode(-100.0)) == -6.0


def test_e2m1_negative_zero_keeps_sign():
    assert e2m1_encode(-0.0) == 8


def test_e2m1_rejects_nan():
    with pytest.raises(ValueError):
        e2m1_encode(np.nan)


def test_e4m3_all_256_codes_roundtrip():
    for c in range(256):
        if c & 0x7F == 0x7F:
            assert np.isnan(e4m3_decode(c)) and e4m3_encode(np.nan) == 0x7F
        else:
            assert e4m3_encode(e4m3_decode(c)) == c, hex(c)


def test_e4m3_special_values():
    assert e4m3_decode(0x7E) == 448.0
    assert e4m3_decode(0x01) == 2.0 ** -9
    assert e4m3_decode(0x08) == 2.0 ** -6
    assert e4m3_decode(0x38) == 1.0
    assert np.isnan(e4m3_decode(0xFF))
    assert np.isinf(E4M3_VALUES).sum() == 0
    assert np.isnan(E4M3_VALUES).sum() == 2


def test_e4m3_saturates():
    assert e4m3_encode(1e9) == 0x7E and e4m3_encode(-1e9) == 0xFE
    assert e4m3_encode(464.0) == 0x7E


@pytest.mark.parametrize("x,code", [
    (1.0625, 0x38),          # tie 1.0 / 1.125 -> even mantissa (1.0)
    (1.1875, 0x3A),          # tie 1.125 / 1.25 -> 1.25
    (2.0 ** -10, 0x00),      # tie 0 / min subnormal -> 0
    (3 * 2.0 ** -10, 0x02),  # tie between 0x01 and 0x02 -> 0x02
    (432.0, 0x7E),           # tie 416 / 448 -> 448 (even)
    (1.06, 0x38), (1.07, 0x39),
])
def test_e4m3_rne(x, code):
    assert e4m3_encode(x) == code


def test_e4m3_round_up_exact_values_unchanged():
    codes = np.arange(127, dtype=np.uint8)
    assert (e4m3_encode_up(e4m3_decode(codes)) == codes).all()


def test_e4m3_round_up_basic():
    assert e4m3_encode_up(1.0000001) == 0x39
    assert e4m3_encode_up(1.06) == 0x39       # RNE would give 1.0
    assert e4m3_encode_up(1e-12) == 0x01      # never rounds a nonzero value to 0
    assert e4m3_encode_up(0.0) == 0
    assert e4m3_encode_up(1000.0) == 0x7E


def test_e4m3_round_up_never_below_input():
    rng = np.random.default_rng(0)
    x = 10.0 ** rng.uniform(-3, 2.6, 5000)
    assert (e4m3_decode(e4m3_encode_up(x)) >= x).all()
    # and it is the smallest such code
    c = e4m3_encode_up(x).astype(int)
    lo = e4m3_decode(np.maximum(c - 1, 0))
    assert ((c == 0) | (lo < x)).all()
