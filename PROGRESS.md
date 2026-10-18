# NVFP4 for Gemmini — Progress Log

Read this first when picking the project back up. Newest entries at the top of **Session log**.
Public write-up: `C:\Users\braed\Portfolio\gemmini-nvfp4.html`.

## Objective
Add NVIDIA's NVFP4 format (E2M1 values, E4M3 per-16-block scale, FP32 tensor scale) to Gemmini.
Approach: integer E2M1 products in the PEs (values ×2 → {0,1,2,3,4,6,8,12}), 13-bit exact
accumulation per 16-element block, per-block scale applied at accumulator drain, streamed from a new scale SRAM.

## Environment (as of 2026-10-10)
- Windows 11, i7-12700H (14C/20T), 16 GB RAM, 716 GB free on C:, NVIDIA GPU (not needed for this project)
- Python 3.11.9, git 2.53 on Windows
- WSL: **not installed**. Docker: not installed.
- Chipyard needs Linux, so the plan is WSL2 + Ubuntu 22.04, with Chipyard cloned into the WSL filesystem (`~/chipyard`), not `/mnt/c`
- `C:\Users\braed\.wslconfig` gives WSL 12 GB RAM + 16 GB swap (Chisel elaboration is memory-hungry)

## Milestones
- [x] M0: Python reference model rebuilt in `refmodel/` (original code wasn't on disk), with its checks passing
- [x] M1: WSL2 + Ubuntu installed (user, admin terminal, reboot)
- [x] M2: Chipyard + Gemmini built; stock Gemmini tests passing in Verilator (verified baseline)
- [x] M3: Scope defined in [docs/M3-scope.md](docs/M3-scope.md). First working version = v2.
- [x] M4 (v0): NVFP4 in software on stock Gemmini: refmodel → C test → Spike + Verilator. Integer block sums bit-exact.
- [x] M5: Bring up Berkeley's MX Gemmini (`ucb-bar/gemmini` branch `gemmini-mx-cleanup` @ `266c593f`, built on MxGen) in `~/chipyard-mx`; its FP4 tests pass in Spike + Verilator. Brief: [briefs/M5-mx-base-bringup.md](briefs/M5-mx-base-bringup.md)
- [ ] M6: NVFP4 on the MX base. **First working version.** Split into checkpoints gated by design debates; see [docs/M6-design-debates.md](docs/M6-design-debates.md):
  - [x] 6.0 Design review: D1-D7 decided
  - [x] 6.1 PE multiplier: synthesis experiment (LUT / case / generic `*` / shift-mux / sign-folded / shared-decode), winner built in Chisel with an exhaustive test. Brief: [briefs/M6.1-pe-multiplier-synthesis.md](briefs/M6.1-pe-multiplier-synthesis.md)
  - [x] 6.2 (Phase A) Exact integer column accumulation: standalone NvFp4Mesh verified + integration plan ([docs/M6.2-integration-plan.md](docs/M6.2-integration-plan.md))
  - [ ] 6.3 E4M3 scale stage + FP32 acc + 16-element blocks + tensor scale
  - [ ] 6.4 libgemmini Spike mirror
  - [ ] 6.5 End-to-end NVFP4 config bit-exact in Spike + Verilator
- [ ] M7: Longer K, performance measurement vs. MX baseline.
- [ ] Later: update the site write-up for the MX-base pivot; publish this repo (LICENSE + README + notices)

## How work is run
Every delegated task follows [AGENT_LOOP.md](AGENT_LOOP.md): brief → step-by-step execution with checks → bounded retries → escalate → structured report → the coordinator re-verifies before ticking a milestone. Briefs live in `briefs/`, step logs in `logs/`.

## Next steps
1. User: decide the integration questions from docs/M6.2-integration-plan.md section 7 (Q1 build type, Q2/Q5 where the scale stage lives + latency, Q3 scale-memory output, Q8 Spike switch). Q4/Q6/Q7 are engineering checks folded into 6.3/6.5.
2. Then write the M6.3 brief (integration into ~/chipyard-mx + scale stage + FP32 acc).
2. User: review the debates D2-D7 in docs/M6-design-debates.md (recommendations given). The old 'exactness' question is D2 there.
3. Add LICENSE (BSD 3-Clause recommended) + README + notices before publishing this repo.

## Environment notes (MX base, `~/chipyard-mx`)
- Shell: `source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh`. Its own RISCV/spike/libgemmini, separate from `~/chipyard`.
- Gemmini 266c593f; mxgen dba3e7e7; rocc-tests 350547f9; libgemmini 876631072.
- Sim: `sims/verilator`, `make CONFIG=MxFp4OnlyGemminiRocketConfig -j8` (454 s, 8.5 GB peak).
- Tests: in `generators/gemmini/software/gemmini-rocc-tests`, `./build_spike.sh` + `./build_mx_rocket.sh bareMetalC`. Spike: `spike --extension=gemmini build_spike/bareMetalC/<t>-baremetal`. RTL: `make CONFIG=MxFp4OnlyGemminiRocketConfig LOADMEM=1 TIMEOUT_CYCLES=200000000 run-binary BINARY=.../build_mx_rocket/bareMetalC/<t>-baremetal`.
- Make doesn't track test data headers: delete the binary to force a rebuild.

## Environment notes (Chipyard)
- Chipyard 1.14.0 (`0acc1e1d`), Gemmini `8c3f9923`, Verilator 5.022, riscv gcc 13.2.0. Lives in WSL `~/chipyard`.
- To get a working shell: `source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh` (`bash -lc` doesn't read .bashrc).
- Build the sim: `cd sims/verilator && make CONFIG=GemminiRocketConfig -j8` (~6 min, peak ~7.3 GB).
- Run a test: `make CONFIG=GemminiRocketConfig run-binary-fast BINARY=../../generators/gemmini/software/gemmini-rocc-tests/build/bareMetalC/<test>-baremetal [TIMEOUT_CYCLES=N]`.
- The Gemmini README's `scripts/setup-paths.sh`, `build-verilator.sh` and `run-verilator.sh` don't exist in this version; use the make targets above.
- conda env was installed by hand from the committed lockfile, because build-setup step 1 broke (Python 3.15 vs conda-lock 2.5.7, and a sysroot 2.35 that doesn't exist).

## Decisions
- 2026-10-17: **New baseline = Berkeley MX Gemmini** (`gemmini-mx-cleanup` @ 266c593f, with MxGen) in `~/chipyard-mx`. NVFP4 is built as deltas on top of it. Stock `~/chipyard` stays as the int8 reference.
- 2026-10-11 (M3): first working version = v2; scales via a reserved scratchpad region + normal mvin; E2M1 as a new Float-style `Arithmetic` type; PE tests in ChiselSim/svsim.
- 2026-10-10: Project code goes in its own repo `C:\Users\braed\gemmini-nvfp4`, separate from the Portfolio site.
- 2026-10-10: Run Chipyard locally on WSL2, not a cloud pod (16 GB RAM is enough for Gemmini + Verilator if swap is set up).

## Session log
### 2026-10-17
- M6.2 Phase A DONE (coordinator verified): pytest 128 pass; by-hand m6.1-s7.sh now runs all 6 Chisel specs (2 PE + 4 mesh), all pass; coordinator mutation (swap the mesh weight-buffer select, confirmed applied) makes the 4 mesh tests fail while the PE tests pass. The DIM=16 mesh is 823 ANDs/PE (+6.4% over the bare PE), depth 71; the MX FP4 PE is 4.5-6.7x larger per PE. The full MX array's synthesis didn't finish (extrapolated, labelled). The agent recommends option (iii), an NVFP4-only config.
- M6.2 Phase A run (subagent, not ticked): `NvFp4Mesh` (hw/nvfp4pe, 16x16 weight-stationary, V6 PEs, exact `SInt(13)` x4 column sums, same pairing/flow/register structure as MX Gemmini's Mesh/PE) is bit-exact vs the refmodel integer block sums: DIM=4 13,248 outputs x3 runs, DIM=16 34,816 + 12,288 outputs incl. the 67 refmodel blocks and both +/-2304 extremes, back-to-back passes with alternating c1/c2, 0 mismatches; two negative controls (carry-in dropped, weight select flipped) fail every test. DIM=16 mesh: 210,635 AIG ANDs (823/PE vs 773 bare PE), 22,016 flops, depth 71. MX FP4 PE (MxFpMul from a copy): 5,165 ANDs depth 175 (BF16 acc) / 3,494 depth 142 (E4M5 acc), i.e. 4.5-6.7x the NVFP4 PE; the full 16x16 MX array synthesis did not finish and is not reported. Integration plan docs/M6.2-integration-plan.md: MX semantics with file:line, 3 options, mesh-to-accumulator boundary; recommends an NVFP4-only config (option iii) with the seam at MeshWithDelays.scala:187. Details: hw/nvfp4pe/RESULTS-mesh.md, logs/m6.2.steps.
- Project report written as a Claude doc: https://claude.ai/code/artifact/6dfe7976-7d12-4660-828d-2fc0198a4aab (status, 2 diagrams, arithmetic, multiplier study, decisions, verification, environment, run-by-hand steps, next, sources). The coordinator ran its by-hand commands: pytest, both Spike runs, and m6.1-s2/s3 pass; m6.1-s7's two PE tests pass, but M6.2's in-progress mesh tests fail in the scratch copy (vector files not copied). The M6.2 agent was told to fix the script. Update the report when 6.2 lands.
- 6.0 done: user decided D3 (exact fixed-function scale stage), D4 (FP32 acc + FP32 mvout), D5 (DIM=16, scaleSize=16), D6 (tensor scale via acc_scale at mvout); D7 recorded. Site date fix: the MX-foundation update is dated Oct 16.
- M6.1 DONE (coordinator verified): re-measured pe_v1/v4/v6 (identical numbers), re-proved Chisel NvFp4PE ≡ full LUT (SUCCESS), mutation (3->2 in NvFp4Mul) correctly FAILs. D1 decided: V6. Site updated.
- M6.1 run (subagent, not ticked): six equivalent NVFP4 PE variants (hw/pe_variants/, Verilog-2005) pass exhaustive iverilog tests vs the golden JSON (256 mul pairs, 393,216 PE vectors each) and are formally proven equivalent to V1 with Yosys miters (negative control fails as required). PE-level AIG ANDs: V4 757, V6 772, V5 797, V2 816, V1 1074, V3 1180. By the fixed rule (within 5% of best -> smaller depth) **V6 wins** (shared decode + sign folded into the adder; depth 63 vs V4's 69). LUT vs case did not converge: ABC leaves the full LUT 42% larger than the structured version. Chisel 6.7.0 `NvFp4PE` (hw/nvfp4pe/) elaborates, passes the exhaustive ChiselSim test (negative control fails), is proven equivalent to V1, and synthesizes to 773 ANDs vs 772 hand-written. Details: hw/pe_variants/RESULTS.md, logs/m6.1.steps.
- Reframed M6 around design debates (docs/M6-design-debates.md) with checkpoints 6.0-6.5. The user asked to deliberately optimize the multiplier HDL for synthesis, so M6.1 is an experiment comparing 6 equivalent PE variants (with Yosys formal equivalence + AIG/gate/depth metrics), with the winner built in Chisel.
- M5 DONE (coordinator verified): re-ran Spike `matmul_tiled_fp4_64x64` + `_128x128x512_requant` (PASSED) and Verilator `fp4_64x64` (PASSED, 104,276 cycles, matching the agent). Agent: all 9 steps pass, negative control fails as expected, `~/chipyard` M4 still 0 mismatches.
- M5 run (subagent, not ticked): `~/chipyard-mx` (Chipyard 1.14.0, gemmini-mx-cleanup @ 266c593f, mxgen dba3e7e7, rocc-tests 350547f9, libgemmini 87663107) built with `MxFp4OnlyGemminiRocketConfig`. Verilator build 454 s, peak ~8.5 GB. Spike: all six branch FP4 tests (64x64, 128x128, 128x128x512, plus requants) PASSED. Verilator: fp4_64x64 104,276 cycles (75 s), 64x64_requant 103,466, 128x128 340,346 (213 s), all PASSED. Negative control fails as expected and passes after restore. `~/chipyard` M4 Spike still 0 mismatches. Per-row acc precision is in `ConfigsFP.scala` `defaultMxFPConfig`: product (4,4) x16 rows, acc sig 5/6/7/8 bits ramp (the FP4-only config inherits it). Details in logs/m5-mx.steps.
### 2026-10-17
- M5 resumed (user confirmed the MX/MxGen base as the new baseline). Agent dispatched from step 1's conda env.
### 2026-10-14
- M5 started, then stopped cleanly because the user had to log off. State: `~/chipyard-mx` clone at 1.14.0 only; partial conda env removed; `~/chipyard` untouched. Helper scripts in `logs/m5-*`.
- Found the integration fork publicly: `ucb-bar/gemmini` branch `gemmini-mx-cleanup` (293 commits on our same base, mostly Nicolas Rakela Herrera + Amanda Shi; active through today). It has MxGen as a submodule, ScaleFactorMem, scaling applied at the array output before accumulation (same as our M3 design), FP4 2-per-byte packing, Chipyard configs, a libgemmini Spike model (branch `mxgemmini-functional-model`), and tests in public `Rakanic/gemmini-rocc-tests`. It's MX, not NVFP4: block 32 (half-parameterized), E8M0 scales (exponent add), BF16 acc, no tensor scale, rounded in-array sums. **Decision (user): use it as the base**, pinned at 266c593f (validated by Chipyard's graphics branch). Re-planned M5-M7. Old M5 (own E2M1 PE) dropped.
- The user noted the original plan was to fork MxGen as the foundation. A read-only survey (Sonnet) found MxGen is a per-element FP MAC PE (`MxFpMul`: outer-product lanes, RNE rounding into BF16-style acc each step, chiseltest, Chisel 6.6, 69 commits by mostly one author, 2026-03 to 10). It has no block/scale support and no Gemmini glue in the repo: test comments point to an unpublished "mxgemmini" Gemmini fork with `generators/gemmini/mxgen` vendored, plus Spike mods. FP32 acc is untested (only (8,8),(4,5),(4,7)), and tests are random (10 trials per combo) except an exhaustive significand-multiplier test. Swapping it in is not trivial without that fork. Decision pending: the user is asked whether they have access to mxgemmini.
- Checked licenses before publishing this repo separately. MxGen (github.com/ucb-bar/MxGen, Berkeley's Chisel generator for low-precision FP/MX datapaths, includes E2M1 + E4M3 and an `MxConfig.mxGemmini` preset) added a LICENSE today (`7044a61`, 2026-10-14): BSD 3-Clause, UC Regents. Before this it had no license, so its code couldn't be reused; now it can, with notice retained. Gemmini/Chipyard/rocc-tests licenses are unchanged (BSD 3-Clause). This repo has no LICENSE yet; it's pending the user's choice. Cloned MxGen read-only to WSL `~/MxGen`.
### 2026-10-11
- M4 DONE (coordinator verified): pytest 126 passed; installed test files identical to the repo's; Spike 0/1280 + 0/512 mismatches, exit 0; my own Verilator re-run EXIT=0, 0 mismatches (K=16: 411 Gemmini cycles, K=64: 949). Negative control by the agent (1 flipped value gives exactly 1 mismatch). Site updated and pushed.
- M4 v0 harness built (subagent, not ticked): refmodel `hw_matmul_v0` + `export_c.py` -> `hw/tests/nvfp4_v0{.c,_data.h}`; integer block sums (full-width int32 mvout) and float32 output bit-exact in Spike and Verilator (0/1280, 0/512). Negative control gives exactly 1 mismatch. Details in hw/README.md and logs/m4-v0.steps.
- M3 drafted in docs/M3-scope.md from a read-only code survey. Key finding: per-block scale can't be applied only at mvout when K > 16, because the accumulator sums across K-tiles. Scaling must happen at the array output (row scalar sA x column vector sB) into an FP32 accumulator. Per-block scaling is exact in FP32. Proposed stages v0 (software on stock HW) -> v1 (E2M1 PE) -> v2 (on-chip scale, K=16) -> v3 (K>16).
- M2 DONE (coordinator verified): matmul (7009 s) and conv (6102 s) both exit 0 with a 150M-cycle cap. All 5 stock tests pass. Gemmini conv took 2,706 cycles vs 11.58M on the CPU.
- M2 mostly done (subagent, ~3h50m): Chipyard + Gemmini built; template, mvin_mvout and tiled_matmul_ws pass. matmul/conv timed out at 22M cycles (sim ~4k cycles/s), not failed. Coordinator re-ran template (PASS) and relaunched matmul/conv with a 150M cap.
### 2026-10-10
- M2 PARTIAL (agent run, not ticked): Chipyard 1.14.0 built in WSL (Verilator 5.022, GemminiRocketConfig sim built in 373s). template, mvin_mvout, tiled_matmul_ws PASS in Verilator; matmul and conv ran clean but hit the cycle cap (22M cycles, ~4k cycles/s) before finishing. build-setup step 1 had to be done by hand (conda-lock/glibc 2.35 issue); setup-paths.sh/build-verilator.sh/run-verilator.sh do not exist in this Gemmini. Details in logs/m2-chipyard.steps.
- M1 done: Ubuntu-22.04 on WSL2, user `braed`, 11 GB RAM visible, 955 GB free, 16 threads, network OK. No reboot needed. sudo requires a password, so the user runs apt steps.
- Coordinator verified M0: re-ran pytest (115 passed) and confirmed 256 E2M1 pairs in vectors. M0 ticked. WSL core installed; Ubuntu distro not yet installed (needs reboot or rerunning `wsl --install -d Ubuntu-22.04`).
- Rebuilt the reference model in `refmodel/` (formats, quant, hw_dot, tiny_transformer, vectors, tests; venv at `.venv`, run `.venv\Scripts\python -m pytest` from repo root). 115 pytest checks pass. Test vectors exported to `refmodel/vectors/`. Finding: hw-style vs dequantize-first is exactly equal in rational arithmetic, but in float64 they differ by ~1e-16 in ~50% of random dots (12/2000 differ after rounding to FP32). M0 left for the coordinator to tick.
- Took stock of the machine: no WSL/Docker/Chipyard. The Python reference model described on the site isn't anywhere on disk, so it has to be rebuilt.
- Created this repo, the log, and `.wslconfig`.
