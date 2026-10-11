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
- [ ] M3: Define the minimum viable first version (scope doc)
- [ ] M4: E2M1 PE + exhaustive 256-pair Chisel unit test
- [ ] M5: Scale SRAM + `mvin_scales` instruction + scale/block alignment at drain
- [ ] M6: Reference-model test vectors through the full array, matching bit for bit

## How work is run
Every delegated task follows [AGENT_LOOP.md](AGENT_LOOP.md): brief → step-by-step execution with checks → bounded retries → escalate → structured report → the coordinator re-verifies before ticking a milestone. Briefs live in `briefs/`, step logs in `logs/`.

## Next steps
1. User: review [docs/M3-scope.md](docs/M3-scope.md) and answer its 4 open questions. Then tick M3 and re-plan M4-M6 around stages v0-v3.
2. Later, update the site write-up: new four-ways numbers (seed 0); "exactly 0 difference" only holds in exact arithmetic; 115 checks; token agreement 81% across 200 seeds.
3. Consider rebuilding Verilator with threads (`VERILATOR_THREADS`) or using Spike for faster functional runs; ~4k cycles/s will be painful for M6.

## Environment notes (Chipyard)
- Chipyard 1.14.0 (`0acc1e1d`), Gemmini `8c3f9923`, Verilator 5.022, riscv gcc 13.2.0. Lives in WSL `~/chipyard`.
- To get a working shell: `source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh` (`bash -lc` doesn't read .bashrc).
- Build the sim: `cd sims/verilator && make CONFIG=GemminiRocketConfig -j8` (~6 min, peak ~7.3 GB).
- Run a test: `make CONFIG=GemminiRocketConfig run-binary-fast BINARY=../../generators/gemmini/software/gemmini-rocc-tests/build/bareMetalC/<test>-baremetal [TIMEOUT_CYCLES=N]`.
- The Gemmini README's `scripts/setup-paths.sh`, `build-verilator.sh` and `run-verilator.sh` don't exist in this version; use the make targets above.
- conda env was installed by hand from the committed lockfile, because build-setup step 1 broke (Python 3.15 vs conda-lock 2.5.7, and a sysroot 2.35 that doesn't exist).

## Decisions
- 2026-10-10: Project code goes in its own repo `C:\Users\braed\gemmini-nvfp4`, separate from the Portfolio site.
- 2026-10-10: Run Chipyard locally on WSL2, not a cloud pod (16 GB RAM is enough for Gemmini + Verilator if swap is set up).

## Session log
### 2026-10-11
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
