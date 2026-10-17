# M6 design debates

Status: **OPEN**. Started 2026-10-17. Each debate ends in a decision record: option chosen, why, and the evidence. M6 work is split into checkpoints, and each one is gated on the debates it depends on.

## Checkpoint review: where we are
| # | Checkpoint | State | Still valid? |
|---|---|---|---|
| M0 | Python reference model + vectors | done | Yes. It's the golden source for E2M1/E4M3/NVFP4 numerics. |
| M2 | Stock Gemmini in `~/chipyard` | done | Yes, as the INT8 reference. |
| M3 | Scope (`docs/M3-scope.md`) | done | **Partly superseded.** The arithmetic analysis still holds (exact block sums, scale before accumulate, exactness of the scale multiply). The "build our own E2M1 Arithmetic type" plan is replaced by the MX base. The scratchpad-region scale path is replaced by MX's ScaleFactorMem. |
| M4 | v0 harness (software NVFP4 on stock HW) | done | Yes. Its test pattern (refmodel → C header → Spike + Verilator, bit-exact) gets ported to the MX base. |
| M5 | MX Gemmini base in `~/chipyard-mx` | done | Yes. This is the new baseline. |

What the MX base already gives us (from the M5 survey; re-confirm any detail before relying on it):
- an FP4 PE (`MxFpMul` via `mac_mx`) doing a 2×2 outer product per PE, with two FP4 values per byte
- `ScaleFactorMem` and scale-load instructions
- scaling applied in `AccumulatorMem` on write, before the accumulate add
- a BF16 accumulator
- per-row rounding of the in-array sums, ramping from 5 to 8 significand bits
- a libgemmini Spike model that mirrors the RTL

---

## D1: How to implement the FP4×FP4 multiply in the PE
**Question**: keep MxGen's floating-point multiply, or add an integer NVFP4 mode?

**Key fact.** Doubled E2M1 magnitudes are {0,1,2,3,4,6,8,12}. Every nonzero one is `m·2^k` with `m ∈ {1,3}` and `k ∈ {0..3}`.
- **Decode** a code (e, m):
  - e=0 → value m, so `m'=1, k=0`, or zero when m=0
  - e≥1, m=0 → `m'=1, k=e`
  - e≥1, m=1 → `m'=3, k=e-1`
- **Product** = `(m'_a·m'_b) · 2^(k_a+k_b)`, where `m'_a·m'_b ∈ {1,3,9}` and the shift is 0..6. The maximum is 9·16 = 144, an 8-bit magnitude. Add a sign XOR and a zero flag.
- So the whole multiplier is a 3-way constant mux ({1,3,9}, 4 bits) plus a 0–6 left shift into 8 bits.

| Option | What it is | For | Against |
|---|---|---|---|
| **A. Keep MxGen `MxFpMul`** | General FP path: decode → 2×2 significand multiply → normalize → round to the product format → FP add | Already validated (by Berkeley's tests); multi-format (FP4/6/8) for free | Rounds in places NVFP4 doesn't need. Normalize/round/FP-add hardware is far bigger than the integer path. Exactness depends on widths it was never tested at. |
| **B. Integer shift-mux mode (recommended)** | Decode to `(sign, m'∈{1,3}, k)`, product = mux{1,3,9} << (k_a+k_b), giving 8-bit magnitude + sign. Same 2×2 lanes per PE, so FP4 throughput matches MX. | Exact by construction. Tiny. Easy to test exhaustively (256 pairs per lane). It's the core "interesting part" to write about. | It's a new PE mode next to MxGen's, which needs a mode select or a separate config. Needs its own exhaustive test plus a Spike-model mirror. |
| C. Lookup table | 6-bit magnitude index (3+3 bits), giving a 64-entry × 8-bit ROM, + sign XOR | Trivially correct, and an obvious golden match | Synthesis reduces it to roughly B anyway. It hides the structure, so there's less to say about it. |

**How to settle**: run the synthesis experiment in [briefs/M6.1-pe-multiplier-synthesis.md](../briefs/M6.1-pe-multiplier-synthesis.md).
- **Framing (2026-10-17).** "LUT vs switch-case vs comb logic" mostly converges after synthesis (ABC minimizes a 64-entry case into the same gates as a hand mux). The structure *around* the multiply is what synthesis won't find on its own:
  - the operand value set (8 magnitudes, not 16)
  - where the sign/negation lives
  - decode shared across the 2×2 outer product
  - fusing the product into the column add
- So the experiment measures each variant at the **PE level** (2 acts × 2 weights → 4 products, each added into a 13-bit column partial sum), not as a bare multiplier.
- The variants are proven formally equivalent, and the winner is picked by a pre-declared rule, then built in Chisel.

**Sub-debate D1b**: replace MxGen's FP4 mode, or add NVFP4 as an extra mode and keep MX FP4? Keeping both makes the comparisons in D8 possible. Recommended: **add a mode**.

## D2: How to accumulate inside the array (down the WS column)
**Question**: should partial sums flowing down the 16 rows be integer or floating point?

| Option | For | Against |
|---|---|---|
| **A. Exact integer, 13-bit signed per lane (recommended, pairs with D1-B)** | Exact (max |sum| = 16·144 = 2304 < 2^12). Integer adders are much smaller than FP adders. Matches the refmodel bit for bit. | Different column datatype from MX's `MxFloat` path. Needs a separate output path into the scale stage. |
| B. MX's FP ramp (5→8-bit significands) | No change | Not exact. NVFP4 results would then match their rounding model, not ours. |
| C. Widen the FP ramp to ≥12-bit significands | Stays inside MxGen's datatype | Larger than A for the same result. Untested widths in MxGen. Spike hardcodes the ramp. |

This also settles the open "exactness" question from the 2026-10-17 session: **A, if D1 = B**.

## D3: The scale stage: E4M3 × E4M3 × isum
Today MX does `applyE9M0Scale`, an exponent add on a BF16 value with no multiplier.

| Option | For | Against |
|---|---|---|
| **A. Exact fixed-function stage (recommended)** | Stage 0: `sA·sB`, a 4×4-bit significand multiply + exponent add (either before the data arrives or in parallel). Stage 1: `isum(13b) × 8b`, giving 21 bits. Stage 2: normalize/pack to FP32 with no rounding. Exact (21 ≤ 24 bits), cheap, and fully pipelined (see the M3 design note). | New code inside `AccumulatorMem`'s scaling block; it has to fit their pipeline and their latency accounting |
| B. A general FP32 multiplier (hardfloat) | Off the shelf | Bigger. Rounds unless it's configured carefully. Wasteful for 13-bit × 8-bit. |
| C. Precombine `sA·sB` into one byte-ish scale in ScaleFactorMem | Fewer multiplies per output | The combined scale needs 8 significand bits + 9 exponent bits, which no longer fits a byte. It also changes their scale memory layout. |

**How to settle**: the latency budget in `AccumulatorMem`, and whether the stage closes timing in their pipeline (Verilator alone can't tell us, so look at logic depth from Yosys).

## D4: Accumulator datatype and width
- **A. FP32 accumulator (recommended).** It matches NVFP4 practice (FP32 accumulation) and our refmodel. The cost is 2× accumulator SRAM width compared with BF16: the capacity halves at the same area, or the area doubles.
- B. BF16 (MX default). Cheaper, but rounds every block add, so it diverges from NVFP4 references for long K.
- Open sub-question: what does mvout emit, FP32 or requantized NVFP4? MX already has a requantizer (BF16 → MX). An NVFP4 requantizer (FP32 → E2M1 + E4M3 + tensor scale) would be a later stretch goal.

## D5: Block size 16 and scale bookkeeping
- With DIM=16, one array pass = one 16-element block (`tilesPerMxBlock = 1`).
- MX hardcodes 32 in `ScaleFactorMem.scala:196` and `LoopMatmul.scala:1118`, while `scaleSize` exists as a config field.
- **Recommended**: make both hardcodes use `scaleSize`, and set `scaleSize = 16` in the NVFP4 config. Also update the matching `/32` assumptions in rocc-tests and libgemmini.
- **Debate**: also keep DIM=32 working (2 blocks per pass) or not? Recommended: **DIM=16 only** for M6.

## D6: The FP32 tensor scale
- A. Reuse the legacy CONFIG_EX `acc_scale` (32-bit, applied at mvout; MX ignores it today). Cheap.
- B. A new config register applied in the scale stage, folded into stage 0 as `tA·tB·sA·sB`. That multiply is no longer exact, because the FP32 tensor scales have 24-bit significands.
- **Recommended: A.** Apply it once at mvout, matching the refmodel's float32 order: `out = acc · (tA·tB/4)`.

## D7: Spike model and verification
- libgemmini mirrors the RTL, so every NVFP4 change goes into both. Debate: which is the golden source?
- **Recommended**:
  - the **refmodel** is golden;
  - libgemmini must match it bit for bit;
  - the RTL must match libgemmini bit for bit.
- Port the M4 harness (exact int block sums + float32 output bits) to the MX test style.
- Keep negative controls in every new test.

## D8: What to measure and compare (sets up M7)
- Accuracy: NVFP4 (exact, FP32) vs MX FP4 (E8M0, rounded, BF16) on the same matrices, plus the tiny transformer.
- Area/logic depth (Yosys): MxGen FP4 PE vs NVFP4 integer PE (D1); BF16 vs FP32 accumulator.
- Cycles: NVFP4 vs MX FP4 on the same matmul sizes in Verilator.

---

## Reframed M6 checkpoints
Each is a mini-milestone, so it gets a brief, a verification and a site update.

| CP | Deliverable | Depends on | Check |
|---|---|---|---|
| **6.0 Design review** | Decisions recorded for D1–D7 in this doc | user | each debate marked DECIDED with its evidence |
| 6.1 Multiplier | NVFP4 PE mode (D1-B) in a standalone wrapper; exhaustive 256-pair test per lane; Yosys area/depth vs MxGen FP4 | D1 | 256/256 exact; area table |
| 6.2 Column accumulation | Integer 13-bit column path + mesh output into the scale stage (D2-A); mesh-level test with refmodel block vectors | D1, D2 | 67/67 refmodel blocks exact |
| 6.3 Scale stage + FP32 acc | E4M3 scale stage (D3-A), FP32 accumulator (D4-A), `scaleSize=16` (D5), tensor scale at mvout (D6-A) | D3–D6 | unit tests: stage output bit-exact vs refmodel |
| 6.4 Spike mirror | libgemmini NVFP4 mode bit-exact vs refmodel | D7 | ported M4 harness passes in Spike |
| 6.5 End to end | NVFP4 config builds; harness passes in Verilator; negative control fails | 6.1–6.4 | bit-exact in Spike + RTL, **first working version** |
| M7 | Comparisons (D8), longer K | 6.5 | report + site write-up |
