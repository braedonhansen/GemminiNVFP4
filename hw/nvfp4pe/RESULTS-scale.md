# M6.3 Phase A results: NVFP4 scale stage + FP32 accumulate

Date: 2026-10-17. Toolchain as in `RESULTS-mesh.md` (Chisel 6.7.0, Verilator via ChiselSim, Yosys via `hw/pe_variants/synth_metrics.sh`). Sources: `src/main/scala/nvfp4pe/NvFp4ScaleStage.scala`, spec `NvFp4ScaleSpec.scala`, model `refmodel/scale_stage.py`, vectors `refmodel/vectors/{scale_stage,acc_seq}.txt.gz`. Scripts: `logs/m6.3a-s7.sh` (tests, same scratch-copy approach as `m6.1-s7.sh`, plus optional mutation and test filter), `logs/m6.3a-neg.sh`, `logs/m6.3a-synth.sh`. Elaborated SV in `generated/`.

## Design
- `NvFp4ScaleStage` (4 lanes, 3 register stages, latency 3 cycles from `in_valid`/inputs to `out_valid`/`out`):
  0. decode E4M3 sA, sB: sP = sigA*sigB (4x4 -> 8 bits), eS = eA'+eB' (5 bits; subnormals: sig = m, exponent field 1), sign, NaN flag.
  1. prod = |isum| * sP (13 x 8 -> 21 bits).
  2. leading-one normalize (priority encoder + shift), pack to FP32.
- `Fp32AccAdd` = hardfloat `AddRecFN(8,24)`, RNE, wrapped by `recFNFromFN`/`fNFromRecFN` (combinational; `Fp32AccAddRec` is the recoded core). `NvFp4ScaleAcc` = scale stage + a per-lane FP32 accumulator register with a `first` flag (acc operand = +0): a block entering at cycle t is in `acc` at t+4 (3 scale + 1 add).
- Hardfloat reuse: 8 files copied from `~/chipyard-mx/generators/hardfloat` (commit 0ecaef09) into `src/main/scala/hardfloat/` (BSD, licence file alongside). MX tree untouched.

## Why stages 0-2 never round
sigA, sigB <= 15 so sP <= 225 (8 bits); |isum| <= 4096 as a 13-bit magnitude (2304 in use) so prod < 2^20, at most 21 bits <= the 24-bit FP32 significand. Biased exponent = eS + 127 - lz in [109, 157], so always a normal FP32 (no overflow, no subnormal). Every block value is a multiple of 2^-18, so sums of blocks also never go subnormal. pytest checks it: the integer stage model equals float32 arithmetic for all 65,536 pairs, and the float64 product equals the FP32 result (no rounding) with max product width <= 21 bits.

## NaN / sign policy (refmodel and RTL identical)
A NaN code (0x7F / 0xFF) in sA or sB gives canonical qNaN 0x7FC00000 for the lane whatever isum is; the FP32 add propagates it (canonical out). The scale sign bits are honoured (sign = sI ^ sA ^ sB, also for a zero result, as IEEE multiply), though NVFP4 scales are positive. Inf cannot occur (|blk| <= 4.6e8).

## Tests (ChiselSim, `sbt "testOnly nvfp4pe.NvFp4ScaleSpec"`, 129 s total)
| Test | Vectors | Mismatches |
|---|---|---|
| scale stage vs refmodel, streaming 4 lanes/cycle: all 65,536 (sA,sB) codes x isum {0,1,-1,2304,-2304,random} = 393,216, plus 100,000 random triples (all codes, NaN codes included) | 493,216 | 0 |
| latency/valid: isolated block, `out_valid` exactly at cycle 3, bubbles | 1 | 0 |
| FP32 accumulate, `NvFp4ScaleAcc`, 12,000 sequences (1-20 blocks; free scales, cancellation, extremes/zeros, signed/NaN codes), back-to-back with `first`, acc checked after every block, 4 independent sequences per run | 126,618 blocks (126,856 lane-steps incl. padding) | 0 |
| `Fp32AccAdd` vs JVM float add: 200k random pairs (subnormals, big gaps, cancellation) | 200,000 | 0 |
pytest: 134 passed (`refmodel/tests/test_scale_stage.py` adds the exactness proofs, NaN/sign policy, agreement with `hw_matmul_v0` order, and a check that the committed gz vectors are current).

Negative control (scratch copy): stage 1 `mag * r0P(i)` -> `mag * r0P(i)(6, 0)` (drops significand bit 7). The mutation was confirmed applied (`grep -c` of the mutated text: 0 before, 1 after, in the copy). Result: scale stage 182,308 of 493,216 mismatches; 2 of 3 tests fail (scale stage and accumulate; the independent adder test is unaffected, as expected).

## Synthesis (`synth_metrics.sh`: AIG = `abc -g AND`, gates = `abc -g cmos2`, depth = `ltp -noff`, i.e. longest register-to-register path)
| Design | AIG ANDs | NOTs | cmos2 gates | depth (ltp) | AND lvl | flops |
|---|---|---|---|---|---|---|
| `NvFp4ScaleStage` (4 lanes, 3 stages) | 4,859 | 4,441 | 8,106 | 96 | n/a | 335 |
| `Fp32AccAddRec` (hardfloat core, comb) | 2,502 | 1,930 | 3,413 | 225 | 144 | 0 |
| `Fp32AccAdd` (+ recode in/out, comb) | 3,443 | 2,694 | 4,669 | 263 | 160 | 0 |
| `NvFp4ScaleAcc` (stage + 4 adders + 4 acc regs) | 18,355 | 15,060 | 25,715 | 262 | n/a | 435 |
Per lane the scale stage is about 1,215 ANDs. "AND lvl" is n/a for designs with flops (`and_levels.py` does not handle them); ltp is the register-to-register figure.

## For Phase B
- The adder is the critical path (ltp 225-263 vs 96 for the whole scale stage): the 4th cycle can be one cycle, but expect it to limit clock rate; `acc_latency` should be sized for scale latency 3 plus the add 1, or the adder split.
- recFN conversion costs +941 ANDs (+38%) and +38 depth per adder. If the accumulator SRAM stores recoded FP32 (33 bits per lane) only the scale-stage output needs recoding and only mvout needs un-recoding; storing standard FP32 keeps the SRAM at 32 bits but pays that cost on every add. Hardfloat is already in the MX tree (`Arithmetic.scala:9`), so no new dependency.
- Stage 2 could emit the recoded form directly (exponent offset only), removing one recode.
- The block value width is 32 bits per lane; the stage takes per-lane sA/sB (caller expands row/column scale bytes to lanes: lane order a0w0, a0w1, a1w0, a1w1).
- Gemmini accumulate adds are not valid-gated per lane: `in_valid` is shared; per-lane enables would need the SRAM write mask.
