# Brief: M5, bring up Berkeley's MX Gemmini (`gemmini-mx-cleanup`) as the new base

Follow `AGENT_LOOP.md`. Read `PROGRESS.md` (Environment notes, and the 2026-10-14 session log) and `docs/M3-scope.md` first.

**Goal**: in a **separate** Chipyard tree `~/chipyard-mx`, build Gemmini at `gemmini-mx-cleanup` commit **266c593f2cb51d7e3fe83fc0317072b585ac3c52**, plus its MX Spike model. Get the branch's own FP4 tests passing in Spike and Verilator. No source modifications. The existing `~/chipyard` (int8 baseline + our M4 harness) must stay untouched and working.

**Why separate**: the branch's `libgemmini` install overwrites `$RISCV/lib/libgemmini.so`, which our M4 Spike checks use. It also halves the int8 scratchpad/accumulator sizes.

**Limits**
- Write only to `~/chipyard-mx`, `~/nvfp4-logs/m5-*`, and `C:\Users\braed\gemmini-nvfp4\logs\`. Treat `~/chipyard` as read-only. No sudo. No commits anywhere except one final commit in the project repo (message prefix `M5:`).
- Time budget: 6 h wall clock. Long steps run under `nohup` with background waits (60–120 s sleeps), as in M2/M4. Never put a pattern in a `pgrep -f` that also appears in your own wait command, because it will match itself. Use `.done` marker files instead.
- Verilator build: `-j8`, dropping once to `-j4` on OOM. The MX design is much larger than stock, so watch memory.
- Skip the `npu-exploration` submodule (SSH URL, not needed).

**Preconditions**: `df -h ~` shows ≥ 150 GB free, `free -g` shows ≥ 11 GB, and `~/chipyard` M4 Spike still passes (`spike --extension=gemmini ~/chipyard/generators/gemmini/software/gemmini-rocc-tests/build/bareMetalC/nvfp4_v0-baremetal`, 0 mismatches). Record that output as the "before" evidence.

## Steps
| # | Step | Check |
|---|------|-------|
| 1 | Clone Chipyard 1.14.0 into `~/chipyard-mx` (use `git clone --reference ~/chipyard` to save download). Set up its own conda env and toolchain the same way M2 did. M2's step-4 deviation applies: build-setup step 1 is broken, so create `.conda-env` from the committed lockfile by hand (see `logs/m2-chipyard.steps`). Skip the FireSim/FireMarshal steps. | `cd ~/chipyard-mx && source env.sh && which riscv64-unknown-elf-gcc spike verilator`, and all paths are under `~/chipyard-mx` |
| 2 | In `~/chipyard-mx/generators/gemmini`: fetch `origin gemmini-mx-cleanup`, `git checkout 266c593f`, then `git submodule update --init mxgen software/gemmini-rocc-tests software/libgemmini`. Record the submodule commits (expected: mxgen dba3e7e7, rocc-tests 350547f9, libgemmini 87663107). | `git -C generators/gemmini log -1 --format=%h` = 266c593f, and `git submodule status` shows the 3 inited |
| 3 | Build and install the MX Spike model: `make -C software/libgemmini install` (into this tree's `$RISCV`). | `ls $RISCV/lib/libgemmini*.so` (expect base, `_dim32`, `_dim8`), with paths under `~/chipyard-mx` |
| 4 | Elaborate and build Verilator for `MxFp4OnlyGemminiRocketConfig`. If that config doesn't exist at this commit, use `MxGemminiRocketConfig` and note it. | the simulator binary exists in `sims/verilator/`; record build time and peak RSS |
| 5 | Copy the generated `gemmini_params.h` into rocc-tests `include/` (follow the libgemmini README / test-script instructions at this commit). Build the Spike binaries (`./build_spike.sh`) and the RTL binaries (`./build_mx_rocket.sh bareMetalC`, `-DMX_ROCKET`). | `matmul_tiled_fp4_64x64-baremetal` exists in both build dirs |
| 6 | Spike: run the FP4 subset of the branch's MX test list (`.github/scripts/defaults.sh`): `matmul_tiled_fp4_64x64`, `_128x128`, `_128x128x512`, plus the `_requant` variants that exist. | each prints PASSED and exits 0 |
| 7 | Verilator: run `matmul_tiled_fp4_64x64` (smallest) with `LOADMEM=1` and a raised `TIMEOUT_CYCLES`. If it passes within budget, also run one `_requant` variant. | PASSED, exit 0; record the simulated cycles and wall time |
| 8 | Negative control: corrupt one expected value in a scratch copy of the 64x64 test's data, rebuild the Spike binary, and run it. | the test FAILS. Then restore and confirm it passes again. |
| 9 | Re-run the "before" check on `~/chipyard`. | M4 Spike `nvfp4_v0` still 0 mismatches (the old tree is unaffected) |

**Done when**: steps 1–9 pass, with evidence in `logs/m5-mx.steps`, plus one dated bullet in the PROGRESS.md session log (don't tick M5).

**Also report (no changes, just observations)**
- Where the per-row mesh accumulator precision is configured (`meshAccPrecisionList` and `meshProdPrecisionList` in `ConfigsFP.scala`) for the config you built.
- Whether an FP4-only config could set every row's accumulator significand to ≥ 13 bits (exact 16-element FP4 block sums) via config alone.

**Known risks**
- The standalone Rocket + Verilator MX path has no CI evidence; upstream CI uses Radiance on VCS. Expect integration breakage. Classify it per AGENT_LOOP.md and escalate rather than patching sources.
- The rocc-tests Makefile gates MX tests on `HAS_MX_SCALING` in `gemmini_params.h`. A stale header silently skips them.
- The Verilator build may take far longer and use more memory than stock Gemmini.
