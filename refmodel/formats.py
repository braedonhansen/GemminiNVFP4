"""Bit-exact E2M1 and E4M3 encode/decode."""
import numpy as np

# E2M1 magnitudes indexed by the 3 low bits (exp<<1 | mantissa).
E2M1_MAGS = np.array([0, 0.5, 1, 1.5, 2, 3, 4, 6], dtype=np.float64)


def _build_e4m3():
    vals = np.zeros(256)
    for c in range(256):
        sign = -1.0 if c & 0x80 else 1.0
        e, m = (c >> 3) & 0xF, c & 7
        if e == 15 and m == 7:
            v = np.nan
        elif e == 0:
            v = (m / 8) * 2.0 ** -6  # subnormal
        else:
            v = (1 + m / 8) * 2.0 ** (e - 7)
        vals[c] = sign * v
    return vals


E4M3_VALUES = _build_e4m3()      # all 256 codes
E4M3_MAGS = E4M3_VALUES[:127]    # finite non-negative codes, increasing
E4M3_MAX = 448.0
E4M3_NAN = 0x7F


def _rne_index(mag, table):
    """Index of the nearest table entry; ties go to the even index.

    Code parity equals mantissa LSB for both formats, so even index = even mantissa.
    """
    mids = (table[:-1] + table[1:]) / 2  # exact in float64
    idx = np.searchsorted(mids, mag, side="left")
    at = np.minimum(idx, len(mids) - 1)
    tie = (idx < len(mids)) & (mag == mids[at])
    return idx + (tie & (idx % 2 == 1))  # tie between idx and idx+1


def e2m1_encode(x):
    """Float -> 4-bit code (uint8), round-to-nearest-even, saturating at 6."""
    x = np.asarray(x, dtype=np.float64)
    if np.isnan(x).any():
        raise ValueError("E2M1 has no NaN")
    code = _rne_index(np.abs(x), E2M1_MAGS)
    return (code | (np.signbit(x) << 3)).astype(np.uint8)


def e2m1_decode(code):
    code = np.asarray(code)
    mag = E2M1_MAGS[code & 7]
    return np.where(code & 8, -mag, mag)


def _e4m3_pack(idx, x):
    return (idx | (np.signbit(x) << 7)).astype(np.uint8)


def e4m3_encode(x):
    """Float -> E4M3 byte, round-to-nearest-even, saturating at +-448. NaN -> 0x7F."""
    x = np.asarray(x, dtype=np.float64)
    idx = _rne_index(np.abs(np.nan_to_num(x)), E4M3_MAGS)
    out = _e4m3_pack(idx, x)
    return np.where(np.isnan(x), E4M3_NAN, out).astype(np.uint8)


def e4m3_encode_up(x):
    """Smallest E4M3 magnitude >= |x| (used for block scales). Saturates at 448."""
    x = np.asarray(x, dtype=np.float64)
    if np.isnan(x).any():
        raise ValueError("NaN scale")
    idx = np.minimum(np.searchsorted(E4M3_MAGS, np.abs(x), side="left"), 126)
    return _e4m3_pack(idx, x)


def e4m3_decode(code):
    return E4M3_VALUES[np.asarray(code, dtype=np.uint8)]
