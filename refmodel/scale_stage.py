"""Bit-exact model of the NVFP4 block-scale stage and FP32 accumulate (M6.3 Phase A).

Pipeline per lane:  isum (signed int13, |isum| <= 2304 in practice)  x  sA (E4M3)  x  sB (E4M3)
  stage 0: decode sA, sB; sP = sigA*sigB (<= 8 bits), eS = eA' + eB' (5 bits)
  stage 1: prod = |isum| * sP (<= 21 bits)
  stage 2: normalize, pack to FP32 (no rounding: prod has <= 21 significant bits < 24)
  then   : acc = acc + blk in FP32 (RNE), one add per K block.

E4M3 conventions (match formats.py): code = s eeee mmm; e == 0 is subnormal (value m/8 * 2^-6);
codes 0x7F and 0xFF are NaN. Scales in NVFP4 are positive (sign bit 0), but the sign bit is
handled as IEEE multiplication does (sign = xor of the three signs, also for a zero result).

NaN policy (DEFINED, not excluded): if sA or sB is a NaN code, the block value is the canonical FP32
quiet NaN 0x7FC00000, whatever isum is (0 * NaN = NaN). The FP32 add then propagates NaN
(canonical NaN out). Inf cannot occur from the scale stage: |blk| <= 2304*448*448 ~ 4.6e8.
Subnormal FP32 cannot occur either: every block value is an integer multiple of 2^-18, so the
smallest non-zero magnitude is 2^-18, and sums of such multiples are again multiples of 2^-18.
"""
import gzip
import struct
from pathlib import Path
import numpy as np
from formats import e4m3_decode

OUT = Path(__file__).parent / "vectors"
QNAN = 0x7FC00000
F32 = np.float32


def f32_bits(x):
    return struct.unpack("<I", struct.pack("<f", F32(x)))[0]


def bits_f32(b):
    return F32(struct.unpack("<f", struct.pack("<I", b & 0xFFFFFFFF))[0])


def canon(x):
    """float32 -> bits, with every NaN mapped to the canonical quiet NaN."""
    x = F32(x)
    return QNAN if np.isnan(x) else f32_bits(x)


def is_nan_code(c):
    return (c & 0x7F) == 0x7F


def scale_stage_f32(isum, sa, sb):
    """Reference by float32 arithmetic in the refmodel order: (isum*sA)*sB. Returns FP32 bits."""
    with np.errstate(all="ignore"):
        x = (F32(isum) * F32(e4m3_decode(sa))) * F32(e4m3_decode(sb))
    return canon(x)


# ---- stage-by-stage integer model (what the RTL implements) ----
def stage0(sa, sb):
    """-> (sP, eS, sign, nan). value(sA)*value(sB) = sP * 2^(eS-20) * (-1)^sign."""
    def dec(c):
        e, m = (c >> 3) & 15, c & 7
        return ((8 | m) if e else m), max(e, 1)
    siga, ea = dec(sa)
    sigb, eb = dec(sb)
    return siga * sigb, ea + eb, ((sa >> 7) ^ (sb >> 7)), is_nan_code(sa) or is_nan_code(sb)


def stage1(isum, sP):
    """-> (prod, sign_isum). prod = |isum| * sP, at most 21 bits."""
    return abs(isum) * sP, int(isum < 0)


def stage2(prod, eS, sign, nan):
    """Normalize and pack to FP32 bits; asserts that nothing is rounded away."""
    if nan:
        return QNAN
    if prod == 0:
        return sign << 31
    p = prod.bit_length() - 1                       # leading-one position, 0..20
    assert p <= 20
    biased = p + eS + 107                           # p + (eS - 20) + 127
    assert 1 <= biased <= 254                       # always a normal FP32
    frac = ((prod << (23 - p)) & 0x7FFFFF)          # exact: p <= 20 < 23
    return (sign << 31) | (biased << 23) | frac


def scale_stage_int(isum, sa, sb):
    sP, eS, s_ab, nan = stage0(sa, sb)
    prod, s_i = stage1(isum, sP)
    return stage2(prod, eS, s_ab ^ s_i, nan)


def fp32_add(acc_bits, blk_bits):
    """FP32 add (RNE) on bit patterns; NaN -> canonical."""
    with np.errstate(all="ignore"):
        return canon(bits_f32(acc_bits) + bits_f32(blk_bits))


def acc_sequence(blocks):
    """blocks: list of (isum, sa, sb). acc starts at +0, float32 order of hw_matmul_v0.
    Returns the list of acc bits after each block."""
    acc, out = 0, []
    for i, a, b in blocks:
        acc = fp32_add(acc, scale_stage_f32(i, a, b))
        out.append(acc)
    return out


# ---- vectors ----
FIXED_ISUMS = [0, 1, -1, 2304, -2304]


def scale_vectors(seed=7, n_random=100_000):
    """Lines (isum, sa, sb, expected bits): all 65,536 (sA, sB) code pairs (NaN codes defined)
    x FIXED_ISUMS + one random isum per pair, plus n_random fully random triples."""
    rng = np.random.default_rng(seed)
    rows = []
    rnd = rng.integers(-2304, 2305, 65536)
    for sa in range(256):
        for sb in range(256):
            for i in FIXED_ISUMS + [int(rnd[sa * 256 + sb])]:
                rows.append((i, sa, sb, scale_stage_f32(i, sa, sb)))
    for _ in range(n_random):
        i = int(rng.integers(-2304, 2305)); sa = int(rng.integers(0, 256)); sb = int(rng.integers(0, 256))
        rows.append((i, sa, sb, scale_stage_f32(i, sa, sb)))
    return rows


def acc_vectors(seed=11, n_seq=12_000):
    """Sequences of (isum, sa, sb) -> acc bits after every block. Mixes: free random scales (huge
    exponent gaps), near-equal scales with opposite signs (cancellation), isum extremes, zeros."""
    rng = np.random.default_rng(seed)
    seqs = []
    for s in range(n_seq):
        kind = s % 4
        n = int(rng.integers(1, 21))
        base = int(rng.integers(0, 0x7F))   # positive finite code
        blocks = []
        for _ in range(n):
            if kind == 0:     # free random, positive scales
                sa, sb = int(rng.integers(0, 0x7F)), int(rng.integers(0, 0x7F))
                i = int(rng.integers(-2304, 2305))
            elif kind == 1:   # near-equal scales, random-sign sums: cancellation
                sa = max(0, min(0x7E, base + int(rng.integers(-1, 2)))); sb = 0x38
                i = int(rng.integers(-2304, 2305))
            elif kind == 2:   # extremes and zeros
                sa, sb = int(rng.choice([0, 1, 8, 0x38, 0x7E])), int(rng.choice([0, 1, 8, 0x38, 0x7E]))
                i = int(rng.choice([0, 1, -1, 2304, -2304]))
            else:             # any code, including negative and NaN codes (rare)
                sa, sb = int(rng.integers(0, 256)), int(rng.integers(0, 256))
                if rng.random() < 0.9:
                    sa &= 0x7F; sb &= 0x7F
                    if is_nan_code(sa): sa = 0x38
                    if is_nan_code(sb): sb = 0x38
                i = int(rng.integers(-2304, 2305))
            blocks.append((i, sa, sb))
        accs = acc_sequence(blocks)
        seqs.append([(i, a, b, c) for (i, a, b), c in zip(blocks, accs)])
    return seqs


def _gz_write(path, text):
    with open(path, "wb") as raw, gzip.GzipFile(fileobj=raw, mode="wb", mtime=0, filename="") as g:
        g.write(text.encode())


def scale_text(rows):
    return "".join(f"{i} {a} {b} {c:08x}\n" for i, a, b, c in rows)


def acc_text(seqs):
    return "".join("S\n" + "".join(f"{i} {a} {b} {c:08x}\n" for i, a, b, c in s) for s in seqs)


def export(outdir=OUT):
    outdir = Path(outdir); outdir.mkdir(exist_ok=True, parents=True)
    rows, seqs = scale_vectors(), acc_vectors()
    _gz_write(outdir / "scale_stage.txt.gz", scale_text(rows))
    _gz_write(outdir / "acc_seq.txt.gz", acc_text(seqs))
    return rows, seqs


if __name__ == "__main__":
    r, s = export()
    print(f"scale_stage vectors: {len(r)}; acc sequences: {len(s)}, blocks: {sum(map(len, s))}")
