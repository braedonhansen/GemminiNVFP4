# Brief: M2, stock Gemmini baseline in Chipyard (WSL2)

Follow `AGENT_LOOP.md`. Run every command inside WSL (`wsl -d Ubuntu-22.04 -- bash -lc '...'`).

**Goal**: stock Chipyard + Gemmini build, and Gemmini's own tests pass in Verilator. No source modifications.

**Limits**
- Write only to `~/chipyard`, `~/nvfp4-logs`, `~/miniforge3`, and `C:\Users\braed\gemmini-nvfp4\logs`
- Time budget: 4 h wall clock. Retry budget: per AGENT_LOOP.md.
- Build parallelism: `-j8` at first. If OOM-killed, drop once to `-j4`, then stop.
- Send long commands' output to `~/nvfp4-logs/<step>.log`. Run them with `nohup` and poll the log, so a dropped tool call doesn't kill the build.

**Preconditions** (check them all, and stop if any fails)
- `wsl -l -v` shows Ubuntu-22.04 at VERSION 2
- In WSL: `free -g` shows ≥ 11 GB total memory, `df -h ~` shows ≥ 100 GB free, `nproc` ≥ 8
- `ping -c1 github.com` succeeds

## Steps (each with a check)
| # | Step | Check |
|---|------|-------|
| 1 | `sudo apt-get update && sudo apt-get install -y build-essential git curl wget bc` | `gcc --version && git --version` |
| 2 | Install Miniforge to `~/miniforge3` (official github.com/conda-forge/miniforge release installer), `conda init bash`, install `conda-lock` | `conda --version && conda-lock --version` |
| 3 | Clone `github.com/ucb-bar/chipyard` into `~/chipyard` and check out the **latest release tag**. Record the tag + commit. | `git -C ~/chipyard describe --tags` |
| 4 | `./build-setup.sh riscv-tools -s 6 -s 7 -s 8 -s 9 -s 10` (skip FireSim/FireMarshal/VLSI steps; check `--help` first and adjust the skip numbers to whatever that release defines) | `source ~/chipyard/env.sh && which riscv64-unknown-elf-gcc && verilator --version` |
| 5 | `cd generators/gemmini && ./scripts/setup-paths.sh` | `ls generators/gemmini/configs` lists the copied config files |
| 6 | `cd generators/gemmini/software/gemmini-rocc-tests && ./build.sh` | `ls build/bareMetalC/*-baremetal` lists binaries (expect `template-baremetal`, `matmul-baremetal`, etc.) |
| 7 | `cd generators/gemmini && ./scripts/build-verilator.sh` (default INT8 config) | the simulator binary exists in `sims/verilator/` |
| 8 | `./scripts/run-verilator.sh template` | log contains a PASS / exit code 0 |
| 9 | Run `matmul`, `conv`, `mvin_mvout`, `tiled_matmul_ws` the same way | each one passes |

**Done when**: steps 1–9 pass, with evidence copied to `C:\Users\braed\gemmini-nvfp4\logs\m2-chipyard.steps`, and the report gives the Chipyard tag, Gemmini commit, Verilator version, build time, and peak memory, if observed.

**Known risks**
- Elaborating Chisel/Scala in step 7 can use 8+ GB. That's what the 16 GB swap in `.wslconfig` is for.
- conda solves can be slow. That isn't a failure unless no log output has appeared for over 30 minutes.
- If `build-setup.sh` step numbering differs from above, follow the release's `--help`, not this table, and note it under Deviations.
