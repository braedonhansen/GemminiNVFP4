"""Numeric RTL check of the NVFP4 integration (informational B2 check): compare every accumulator SRAM write printed by the
temporary debug printf in AccumulatorMem ("NVACC <addr> <2048-bit data>") against the refmodel float32 order.

Data: M5 matmul_fp4_64x64 header (A_in_hw [32][64]: byte[r][k] = row 2r low nibble, 2r+1 high nibble; B_in [64][32]: byte[k][c]
= col 2c low, 2c+1 high), scales from the scratch test generator (E4M3 bytes, 4 K-blocks of 16).
Expected per pass p = (k, j, i) (i fastest, then j, then k), write c = 0..15: entry e (0..15), lane l (0..3):
  row m = 32 i + 2c + (e >= 8),  col n = 32 j + 4 (e % 8) + l,
  blk_k = isum_k(m, n) * sA[k][m] * sB[k][n]  (exact),   acc_0 = blk_0,   acc_k = fl32(acc_{k-1} + blk_k)
isum_k = sum over the 16 k of the block of (doubled E2M1 a) * (doubled E2M1 b).
"""
import re, sys
import numpy as np

hdr = open(sys.argv[1]).read()
log = open(sys.argv[2]).read().splitlines()

def arr(name, rows, cols):
    m = re.search(r"static const uint8_t %s\[\d+\]\[\d+\] = \{(.*?)\};" % name, hdr, re.S)
    nums = [int(x, 16) for x in re.findall(r"0x([0-9a-fA-F]{2})", m.group(1))]
    assert len(nums) == rows * cols, (name, len(nums))
    return np.array(nums, dtype=np.uint8).reshape(rows, cols)

A = arr("A_in_hw", 32, 64)
B = arr("B_in", 64, 32)
D = [0, 1, 2, 3, 4, 6, 8, 12]
def dbl(code):
    mag = D[code & 7]
    return -mag if code & 8 else mag
Am = np.zeros((64, 64), dtype=np.int64)   # [m][k]
for r in range(32):
    for k in range(64):
        Am[2 * r, k] = dbl(A[r, k] & 0xF)
        Am[2 * r + 1, k] = dbl(A[r, k] >> 4)
Bm = np.zeros((64, 64), dtype=np.int64)   # [k][n]
for k in range(64):
    for c in range(32):
        Bm[k, 2 * c] = dbl(B[k, c] & 0xF)
        Bm[k, 2 * c + 1] = dbl(B[k, c] >> 4)

def gen(kk, idx, sel):
    x = (kk * 7919 + idx * 104729 + sel * 13 + 12345) & 0xffffffff
    x ^= (x << 13) & 0xffffffff; x ^= x >> 17; x ^= (x << 5) & 0xffffffff
    e = 4 + (x % 8); m = (x >> 8) & 7
    if (x >> 20) % 29 == 0:
        e = 0; m = (x >> 12) & 7
    return (e << 3) | m
def e4m3(c):
    e, m = (c >> 3) & 15, c & 7
    return (m / 8.0) * 2.0 ** -6 if e == 0 else (1 + m / 8.0) * 2.0 ** (e - 7)
import os
NEG = os.environ.get("NEG")   # negative control: wrong K-block index for the activation scales
sA = [[e4m3(gen(k ^ (1 if NEG else 0), i, 1)) for i in range(64)] for k in range(4)]
sB = [[e4m3(gen(k, i, 2)) for i in range(64)] for k in range(4)]

def blk(k, m, n):
    isum = int(np.dot(Am[m, 16 * k:16 * k + 16], Bm[16 * k:16 * k + 16, n]))
    return np.float32(isum * sA[k][m] * sB[k][n])      # float64 product is exact (<= 21 bits), cast does not round

acc = np.zeros((64, 64), dtype=np.float32)
exp_writes = []
for k in range(4):
    for j in range(2):
        for i in range(2):
            for c in range(16):
                vals = np.zeros((16, 4), dtype=np.float32)
                for e in range(16):
                    m = 32 * i + 2 * c + (1 if e >= 8 else 0)
                    for l in range(4):
                        n = 32 * j + 4 * (e % 8) + l
                        b = blk(k, m, n)
                        acc[m, n] = b if k == 0 else np.float32(acc[m, n] + b)
                        vals[e, l] = acc[m, n]
                exp_writes.append((k, j, i, c, vals.copy()))

got = []
for ln in log:
    mm = re.match(r"\s*NVACC ([0-9a-f]+) ([0-9a-f]+)", ln)
    if mm:
        got.append((int(mm.group(1), 16), int(mm.group(2), 16)))
print(f"expected writes {len(exp_writes)}, observed {len(got)}")
if len(got) != len(exp_writes):
    print("COUNT MISMATCH"); sys.exit(1)
bad = 0; n_vals = 0
for idx, ((k, j, i, c, vals), (addr, data)) in enumerate(zip(exp_writes, got)):
    for e in range(16):
        for l in range(4):
            w = (data >> (128 * e + 32 * l)) & 0xffffffff
            exp = int(vals[e, l].view(np.uint32))
            n_vals += 1
            if w != exp:
                bad += 1
                if bad <= 12:
                    print(f"MISMATCH write#{idx} (k={k},j={j},i={i},c={c}) e={e} l={l} addr={addr} got={w:08x} exp={exp:08x}")
print(f"RESULT numeric RTL check: {n_vals} FP32 values compared over {len(got)} accumulator writes, mismatches={bad}")
print("distinct acc addresses:", sorted(set(a for a, _ in got))[:4], "...", len(set(a for a, _ in got)))
sys.exit(1 if bad else 0)
