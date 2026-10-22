"""Scalar, line-by-line port of libgemmini's MX arithmetic (mx_fp_math.h + the `mx_loop_ws_spad` FP4 / E4M3 path),
used only by tests as an independent check of the vectorized refmodel/mx.py.

Port of the logic of ucb-bar/gemmini libgemmini @ 87663107 (BSD 3-Clause, (c) The Regents of the University of
California). Written from the C++ source, one function per C++ function, float32 operations via numpy scalars."""
import math
import numpy as np

f32 = np.float32


def f32_to_bf16_rne(x):
    x = f32(x)
    if x == 0:
        return 0
    bits = int(x.view(np.uint32))
    if ((bits >> 23) & 0xFF) == 0xFF:
        bf = bits >> 16
        if (bits & 0x7FFFFF) and not (bf & 0x40):
            bf |= 0x40
        return bf & 0xFFFF
    lsb = (bits >> 16) & 1
    rounded = (bits + 0x7FFF + lsb) & 0xFFFFFFFF
    out = (rounded >> 16) & 0xFFFF
    if (out & 0x7FFF) == 0:
        return 0
    return out


def bf16_to_f32(bf):
    return f32(np.uint32(bf << 16).view(np.float32))


def bf16_round(x):
    return bf16_to_f32(f32_to_bf16_rne(x))


def product_saturate(x):
    if abs(x) == 0:
        return f32(0)
    max_normal = f32(math.ldexp(1.0 + 6 / 8, 8))
    sat = f32(math.ldexp(1.0 + 6 / 8, 8))
    if abs(x) > max_normal:
        return -sat if np.signbit(x) else sat
    return x


def product_quantize_trunc(x):
    x = f32(x)
    if not np.isfinite(x) or x == 0:
        return product_saturate(x)
    m, e = math.frexp(abs(float(x)))
    E = e - 1
    if E < -16:
        return f32(0)
    frac = 2.0 * m - 1.0
    frac_q = math.floor(frac * 8) / 8
    val = f32(math.ldexp(1.0 + frac_q, E))
    out = -val if np.signbit(x) else val
    return product_saturate(out)


def _round_div_pow2_rne(n, shift):
    if shift <= 0:
        return n << (-shift)
    q = n >> shift
    rem = n & ((1 << shift) - 1)
    half = 1 << (shift - 1)
    if rem > half or (rem == half and (q & 1)):
        q += 1
    return q


def fp_quantize_rne_scalar(x, e_bits, m_bits):
    x = f32(x)
    if np.isnan(x):
        return f32(np.nan)
    if np.isinf(x):
        return x
    if x == 0:
        return f32(0)
    neg = bool(np.signbit(x))
    bits = int(abs(x).view(np.uint32))
    mant = bits & 0x7FFFFF
    e_raw = (bits >> 23) & 0xFF
    if e_raw == 0:
        num, exp2 = mant, 1 - 127 - 23
    else:
        num, exp2 = (1 << 23) | mant, e_raw - 127 - 23
    p = num.bit_length() - 1
    E = exp2 + p
    bias = (1 << (e_bits - 1)) - 1
    emin, emax = 1 - bias, bias
    if E < emin:
        shift = (emin - m_bits) - exp2
        sub_sig = _round_div_pow2_rne(num, shift)
        if sub_sig == 0:
            return f32(0)
        if sub_sig >= (1 << m_bits):
            total = sub_sig
            Ef = emin
            if total >= (1 << (m_bits + 1)):
                total >>= 1
                Ef += 1
            if Ef > emax:
                return f32(-np.inf if neg else np.inf)
            r = f32(math.ldexp(float(total), Ef - m_bits))
            return -r if neg else r
        r = f32(math.ldexp(float(sub_sig), emin - m_bits))
        return -r if neg else r
    total = _round_div_pow2_rne(num, p - m_bits)
    if total >= (1 << (m_bits + 1)):
        total >>= 1
        E += 1
    if E > emax:
        return f32(-np.inf if neg else np.inf)
    r = f32(math.ldexp(float(total), E - m_bits))
    return -r if neg else r


def fp_quantize_rne(x, e_bits, m_bits):
    if (e_bits, m_bits) == (8, 7):
        return bf16_round(x)
    return fp_quantize_rne_scalar(x, e_bits, m_bits)


def fp_add_exact(x, y, e_bits, m_bits):
    x, y = f32(x), f32(y)
    if np.isnan(x) or np.isnan(y):
        return f32(np.nan)
    if np.isinf(x) or np.isinf(y):
        if np.isinf(x) and np.isinf(y) and np.signbit(x) != np.signbit(y):
            return f32(np.nan)
        return x if np.isinf(x) else y
    if x == 0:
        return y
    if y == 0:
        return x
    return fp_quantize_rne_scalar(f32(x + y), e_bits, m_bits)


def bf16_accum_add(x, y):
    return fp_add_exact(bf16_round(x), bf16_round(y), 8, 7)


def e8m0_decode(code):
    return f32(math.ldexp(1.0, int(code) - 127))


def matmul(av, bv, a_sc, b_sc, ramp):
    """av (M, K) float32 element values, bv (K, N), a_sc (M, G) / b_sc (G, N) E8M0 codes. Returns (M, N) float32."""
    M, K = av.shape
    N = bv.shape[1]
    out = np.zeros((M, N), dtype=np.float32)
    for r in range(M):
        for c in range(N):
            acc_bits = 0
            for kt in range(K // 16):
                ct = f32(0)
                for kk in range(16):
                    ae, am = ramp[kk]
                    p = product_quantize_trunc(f32(av[r, kt * 16 + kk]) * f32(bv[kt * 16 + kk, c]))
                    cq = fp_quantize_rne(ct, ae, am)
                    pq = fp_quantize_rne(p, ae, am)
                    ct = fp_add_exact(cq, pq, ae, am)
                g = (kt * 16) // 32
                e = int(a_sc[r, g]) + int(b_sc[g, c]) - 127
                s = e8m0_decode(0 if e < 0 else (254 if e > 254 else e))
                scaled = bf16_round(f32(ct * s))
                prev = bf16_to_f32(acc_bits)
                acc_bits = f32_to_bf16_rne(bf16_accum_add(prev, scaled))
            out[r, c] = bf16_to_f32(acc_bits)
    return out
