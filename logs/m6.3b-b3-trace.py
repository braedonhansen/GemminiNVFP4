"""B3 (Q4): scale-memory address trace for the NVFP4 config (DIM = 16, scaleSize = 16 -> tilesPerMxBlock = 1, kScaleShift = 0).

Transcribes, line for line, the counter and address logic of ScaleFactorMem.scala (nvfp4 branch unchanged in the counters):
  counters  : lines 75-111   (counter_{i,j,k}_runtime advance on read_fire_d1 when scale_counter == numScaleRows-1)
  scale_cnt : lines 316-322  (+1 per accumulator write that reads the scale memory, wraps at 16)
  addresses : lines 194-206  read_row_addr_act = bound_i * (k >> kScaleShift) + i ;  read_row_addr_w = bound_j * (k >> kScaleShift) + j
  first write of a pass (scale_counter == 0) loads the banks (read_fire_real, :234) -> 32 act bytes + 32 weight bytes
and compares with the mesh pass order of LoopMatmulExecute (LoopMatmul.scala:~495: i fastest, then j, then k) and with the
mathematical requirement: pass (k, j, i) is the K-block k of C tile (i, j), so it needs sA of K-block k for the 32 rows of tile
pair i, and sB of K-block k for the 32 columns of tile pair j.
Scale-memory row r = 32 contiguous bytes (two 16-byte bank lines): the loader (MX_LOAD_SCALES, linear) lands A_scales[kblk][m] at
byte kblk*M + m, i.e. row kblk*tiles_I + (m // 32), byte (m % 32); the same for B with tiles_J.
"""
import sys

M, N, K = 64, 64, 64
DIM = 16
scaleSize = 16
tiles_I, tiles_J, tiles_K = M // DIM // 2, N // DIM // 2, K // DIM   # quad: a pass covers 32 (M) x 32 (N) x 16 (K)
tilesPerMxBlock = scaleSize // DIM
kScaleShift = (tilesPerMxBlock - 1).bit_length() if tilesPerMxBlock > 1 else 0
numScaleRows = DIM

# ---- hardware counters (ScaleFactorMem.scala:75-111, 316-322) ----
ci = cj = ck = 0
scale_counter = 0
passes = []
n_writes = tiles_I * tiles_J * tiles_K * numScaleRows
for w in range(n_writes):
    c = scale_counter
    if c == 0:   # read_fire_real: banks addressed with the counters as of this write
        passes.append(dict(row_act=tiles_I * (ck >> kScaleShift) + ci, row_w=tiles_J * (ck >> kScaleShift) + cj,
                           ci=ci, cj=cj, ck=ck))
    # scale_counter increments at the fire; the counter update below is evaluated one cycle later (read_fire_d1), when
    # scale_counter already holds c+1, but the condition in the RTL tests `scale_counter == numScaleRows-1` at that time,
    # i.e. it fires for the write with c == numScaleRows-2 (so the new row is in place before the next pass's first write).
    scale_counter = (c + 1) % numScaleRows
    # read_fire_d1 of this write: evaluate with the post-increment scale_counter of *this* write's successor value
    # (writes issue back to back, so at d1 the register holds c+1)
    sc_now = scale_counter
    last_i = ci == tiles_I - 1
    last_j = cj == tiles_J - 1
    last_k = ck == tiles_K - 1
    if sc_now == numScaleRows - 1:
        if last_i:
            ci = 0
        else:
            ci += 1
        if last_i:
            if last_j:
                cj = 0
            else:
                cj += 1
        if last_i and last_j:
            if last_k:
                ck = 0
            else:
                ck += 1

# ---- expected schedule (LoopMatmulExecute: i fastest, then j, then k) ----
exp = [(k, j, i) for k in range(tiles_K) for j in range(tiles_J) for i in range(tiles_I)]
assert len(passes) == len(exp), (len(passes), len(exp))
ok = True
print(f"M=N=K=64, DIM=16, scaleSize=16 -> tiles_I={tiles_I} tiles_J={tiles_J} tiles_K={tiles_K}, tilesPerMxBlock={tilesPerMxBlock}, kScaleShift={kScaleShift}")
print("pass | mesh pass (k,j,i) | hw counters (k,j,i) | A-scale row (bytes) | B-scale row (bytes) | need: A K-block k, tile i | need: B K-block k, tile j | OK")
for p, (hw, (k, j, i)) in enumerate(zip(passes, exp)):
    need_a = k * tiles_I + i     # row of A_scales[k][32*i .. 32*i+31]
    need_b = k * tiles_J + j
    good = (hw['ck'], hw['cj'], hw['ci']) == (k, j, i) and hw['row_act'] == need_a and hw['row_w'] == need_b
    ok &= good
    print(f"{p:4d} | ({k},{j},{i})          | ({hw['ck']},{hw['cj']},{hw['ci']})            | row {hw['row_act']:2d} = A_scales[k={k}][m={32*i}..{32*i+31}] | "
          f"row {hw['row_w']:2d} = B_scales[k={k}][n={32*j}..{32*j+31}] | row {need_a:2d} | row {need_b:2d} | {'OK' if good else 'BAD'}")
print("ALL PASSES OK" if ok else "MISMATCH")

# ---- per-write sA / sB selection inside one pass (ScaleFactorMem.scala nvfp4 branch) ----
print("\nWithin a pass: write c (0..15) -> accumulator entries e (0..15), lanes j (0..3):")
print("  sA(e) = act_byte[2c + (e >= 8)]   (output row 32*i + 2c + (e>=8); entry e<8 = even row, e>=8 = odd row, as ExecuteController packs)")
print("  sB(e, l) = wgt_byte[4*(e % 8) + l]  (output column 32*j + 4*(e%8) + l)")
for c in (0, 1, 15):
    print(f"  write c={c:2d}: entries 0..7 -> sA byte {2*c:2d}; entries 8..15 -> sA byte {2*c+1:2d}; entry e lane l -> sB byte 4*(e%8)+l")
sys.exit(0 if ok else 1)
