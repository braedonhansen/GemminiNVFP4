# Brief: M4 (v0), NVFP4 in software on stock Gemmini

Follow `AGENT_LOOP.md`. Read `docs/M3-scope.md` (the "design correction" and the v0 row) and the "Environment notes (Chipyard)" in `PROGRESS.md` first.

**Goal**: an end-to-end harness. The reference model produces NVFP4 matrices, and a bare-metal C test runs the integer part on **unmodified** Gemmini, applies the scales on the CPU, and checks results against the reference model. This harness gets reused by M5–M7.

**Method** (weight-stationary, DIM=16)
- A is M×K and B is K×N, with M = N = 16 and K ∈ {16, 64}. Both are NVFP4-quantized along K (blocks of 16).
- For each K block kb: mvin A's codes **decoded to doubled signed integers** (int8 values in {0,±1,±2,±3,±4,±6,±8,±12}) and B's codes the same way, then preload B and compute. Do not accumulate across blocks.
- mvout each block's **full-width int32** accumulator rows. The default mvout clips to int8, so use the full-accumulator read path (`full_C` / `read_full_acc_row`, see how `gemmini.h` and the existing tests do it).
- Check 1 (bit-exact): every block's integer sums == refmodel's integer sums.
- On the CPU, in float32 and in this exact order: `blk = (float)isum * sA[i,kb] * sB[kb,j]`, then `acc += blk` with kb ascending from acc = 0, then `out = acc * (tA*tB/4)`.
- Check 2 (bit-exact): `out` == refmodel output computed in the **same float32 order**. Add that ordering to the refmodel as a function, e.g. `hw_matmul_v0()`, with pytest coverage.

**Allowed paths**
- `C:\Users\braed\gemmini-nvfp4` (refmodel additions, `hw/tests/`, `logs/`)
- In WSL: `~/nvfp4-logs`. Under `~/chipyard/generators/gemmini/software/gemmini-rocc-tests/bareMetalC/` only, add files named `nvfp4_*` plus one line in that directory's Makefile test list. Record the exact diff in the report.
- No changes to any Chisel/Scala source. No sudo. No commits in `~/chipyard`. Commits in the project repo only at the very end, one commit, if the coordinator brief allows (it does: one commit with message prefix `M4:`).

**Limits**: 3 h wall clock. Retry budget per AGENT_LOOP.md. Long runs go under `nohup` with detached polling, as in M2.

## Steps
| # | Step | Check |
|---|------|-------|
| 1 | Add `hw_matmul_v0()` + `export_c_header()` to refmodel, writing `hw/tests/nvfp4_v0_data.h`: decoded int8 A/B per block, E4M3 scales as float values, tA/tB, expected int32 block sums, expected float32 outputs as **bit patterns** (uint32). Fixed seeds; K=16 and K=64 cases. | `.venv\Scripts\python -m pytest -q` all pass (previous 115 plus new tests) |
| 2 | Write `hw/tests/nvfp4_v0.c` (prints the mismatch count per check and returns nonzero on any mismatch). Copy it and the header into bareMetalC as `nvfp4_v0.c` / `nvfp4_v0_data.h` and add it to the Makefile. | `./build.sh` (or `make` in the build dir) produces `nvfp4_v0-baremetal` |
| 3 | Run in **Spike** with the Gemmini extension (find the right invocation in Chipyard 1.14 docs/env; record it). If Spike + Gemmini isn't available, record why and skip to 4. | prints 0 mismatches on both checks, exit 0 |
| 4 | Negative control: flip one expected value in a scratch copy of the header, rebuild, rerun (Spike if available, else Verilator), then restore. | the test FAILS with exactly 1 mismatch (proves the checker works) |
| 5 | Run in **Verilator** (`run-binary-fast`, raise `TIMEOUT_CYCLES` as needed; keep the matrices small so this takes < 30 min). | exit 0, 0 mismatches; record the cycle count |
| 6 | Add a `hw/README.md` with the exact build and run commands for this harness. | the file exists, and the commands in it are the ones you ran |

**Done when**: steps 1–6 pass, with evidence in `logs/m4-v0.steps`, plus one dated bullet in the PROGRESS.md session log. Don't tick M4; the coordinator will.

**Known risks**
- Default mvout clips to int8. If the integer sums look clipped at ±127, you're on the wrong mvout path.
- Spike's Gemmini model may be functional-only and may not match the Verilator config's parameters (DIM, acc width). Check `gemmini_params.h` matches.
- float32 on the Rocket core: make sure the test is compiled with hardware FP, or at least IEEE-correct soft-float. RNE is required for bit-exactness.
