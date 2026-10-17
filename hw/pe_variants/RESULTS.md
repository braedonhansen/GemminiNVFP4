# M6.1 results: NVFP4 PE multiplier variants

Date: 2026-10-17. Tools: Yosys 0.69+ (conda-forge, git 9f09efcdb), Icarus Verilog 13.0, Chisel 6.7.0 / Scala 2.13.16 / sbt 1.8.2, firtool 1.75.0 (from chipyard-mx, read-only), Verilator 5.022.

Numerics (checked against `refmodel/formats.py` and `refmodel/vectors/e2m1_pairs.json` before any HDL): operands are **doubled** E2M1 values (magnitudes {0,1,2,3,4,6,8,12}); `product` = signed product of the doubled values, range -144..144, `product_9bit` is its 9-bit two's complement; code 8 (-0) multiplies to 0; sign = a[3]^w[3].

## Verification
| Check | Result |
|---|---|
| iverilog, all 256 (a,w) for each `mul_*` vs golden hex | 0 mismatches, V1-V6 |
| iverilog, all 65,536 (a0,a1,w0,w1) x 6 c-sets (0, +3951, -3952, mixed, 2 random) = 393,216 vectors per `pe_*` | 0 mismatches, V1-V6 |
| Yosys miter + `sat -verify -prove-asserts` vs V1, `mul_*` and `pe_*` | all 10 proofs pass (V2-V6) |
| Negative control: V4 with the 3x3 entry changed 9 -> 8 | miter FAILS (mul and pe); iverilog TB also fails (36/256 and 146,016/393,216 mismatches) |
| Chisel `NvFp4Mul` / `NvFp4PE` proved equivalent to V1 | both pass |

Proof flow: `proc; memory_map; opt_clean` on each side (the `case` tables become ROM `$mem` cells that SAT cannot model otherwise), `miter -equiv -flatten -make_assert`, `sat -verify -prove-asserts -show-ports`.

## Metrics (fixed script: `synth_metrics.sh`)
- AIG ANDs: `synth -flatten -top X; abc -g AND; stat`, count of `$_AND_` (inverters are free in an AIG; counts are shown in the CSVs).
- gates: `synth -flatten -top X; abc -g cmos2; stat`, total cells (NAND/NOR/NOT).
- depth: `ltp -noff` after `abc -g AND` (longest path in cells, counting inverters). This is the depth used by the decision rule. Supplementary column "AND lvl": longest path counting only AND cells (inverters free), computed by `and_levels.py` from a JSON dump.
- Results are deterministic (two full runs diff-identical).

| Variant | mul AND | mul gates | mul depth | mul AND lvl | pe AND | pe gates | pe depth | pe AND lvl |
|---|---|---|---|---|---|---|---|---|
| V1 full LUT | 206 | 251 | 26 | 14 | 1074 | 1564 | 63 | 35 |
| V2 magnitude LUT + sign | 123 | 146 | 25 | 17 | 816 | 1194 | 72 | 39 |
| V3 decode + generic `*` | 226 | 396 | 42 | 25 | 1180 | 1976 | 79 | 42 |
| V4 structured shift-mux | **93** | 153 | 25 | 14 | **757** | 1141 | 69 | 38 |
| V5 V4 + sign folded in adder | 106 | 177 | 26 | 14 | 797 | 1195 | **59** | 32 |
| V6 V5 + shared decode | 106 | 177 | 26 | 14 | 772 | 1164 | 63 | 34 |
| Chisel `NvFp4PE`/`NvFp4Mul` (= V6) | 105 | 175 | 26 | 14 | 773 | 1180 | 60 | 34 |

Raw: `metrics_hand.csv`, `metrics_chisel.csv`. Note: `mul_v5` and `mul_v6` are the same function with the same structure by construction (sign fold and decode sharing only exist at PE level), so their identical numbers are expected.

## Decision (rule fixed in advance in the brief)
Winner = smallest PE-level AIG AND count; if within 5% of the best, prefer smaller depth, then readability.
- Best PE AND count: **V4 = 757**. The 5% band is <= 794.
- Within the band: V4 (757, depth 69) and V6 (772, +2.0%, depth 63). V5 (797, +5.3%) is just outside; V2 (+7.8%), V1 (+41.9%), V3 (+55.9%) are far outside.
- V6 has the smaller depth (63 vs 69 on `ltp`; 34 vs 38 AND levels) -> **winner: V6** (shared decode + sign folded into the column adder).
- V4 vs V6 on AND count alone (2%) is "not separable by this method"; the depth tie-break is what picks V6. V6 is also the structure that matches how the PE will be reused in the array (each activation/weight decoded once per PE).

## Chisel vs hand-written (Phase B)
Chisel 6.7.0 `NvFp4PE` is V6 written with Chisel (`hw/nvfp4pe/src/main/scala/nvfp4pe/NvFp4PE.scala`). Generated SV is in `hw/nvfp4pe/generated/`.

| | AIG ANDs | gates | depth (ltp) | AND lvl |
|---|---|---|---|---|
| hand `pe_v6` | 772 | 1164 | 63 | 34 |
| Chisel `NvFp4PE` | 773 (+0.1%) | 1180 (+1.4%) | 60 | 34 |
| hand `mul_v6` | 106 | 177 | 26 | 14 |
| Chisel `NvFp4Mul` | 105 | 175 | 26 | 14 |

Within the 10% requirement; no rewrite needed. Chisel `NvFp4PE` and `NvFp4Mul` are formally equivalent to V1. ChiselSim (Verilator) tests: `NvFp4Mul` all 256 pairs vs golden JSON: 0 mismatches; `NvFp4PE` 77,826 combos (all 65,536 at c=0 + 12,288 bound spot checks at c=+4095-144, -4096+144, mixed + the +/-144 extremes landing exactly on 4095/-4096): 0 mismatches. Negative control (9 -> 8 in a scratch copy): both tests FAIL (36/256, 31,250/77,826 mismatches); the repo copy is untouched and passes.

## Observations
- LUT vs case did **not** converge after synthesis. The full 256-entry LUT (V1) is 42% larger than the structured V4 at PE level (1074 vs 757) and 2.2x at mul level (206 vs 93); the 64-entry magnitude LUT (V2) is +32% at mul level and +7.8% at PE level. ABC does not recover the m*2^k structure from a truth table, so the "ABC minimizes it to the same gates" hypothesis in D1 is false for this ABC script.
- Generic `*` (V3) is the worst at every level; Yosys does not exploit that the operands have only 8 magnitudes.
- Sign folding (V5) did not reduce the AND count by itself (797 vs 757 for V4); it cut depth (59, the shallowest). Shared decode (V6) recovered 25 ANDs vs V5. Most of the PE-level gain over V1 comes from the structured magnitude path (V4), not from the fold.

## Caveats
Generic-gate and AIG counts are technology-independent proxies. A real standard-cell library (e.g. sky130) could reorder close results. Results within 10% are **not separable by this method**: V4/V6 (2%), V5 vs V4/V6 (5-6%), and Chisel vs hand V6 (0.1%) fall in that class; V2 vs the V4/V5/V6 group (8-8.5% at PE level) is borderline. ABC results also depend on the ABC version bundled with this Yosys.
