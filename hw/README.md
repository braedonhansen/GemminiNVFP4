# hw/: NVFP4 on Gemmini, test harness

M4 v0: the integer part of an NVFP4 matmul runs on **unmodified** Gemmini; the CPU applies the
E4M3 block scales and the tensor scale in float32. The reference model produces the expected values.

## Files
- `tests/nvfp4_v0.c`: bare-metal test (16x16 output, K = 16 and K = 64, weight-stationary).
- `tests/nvfp4_v0_data.h`: generated test vectors (do not edit by hand).
- Reference: `refmodel/hw_dot.py::hw_matmul_v0` (float32 order) and `refmodel/export_c.py` (header writer).

## 1. Regenerate the vectors and run the Python tests (Windows, repo root)
    .venv\Scripts\python -m pytest -q
    .venv\Scripts\python refmodel\export_c.py hw\tests\nvfp4_v0_data.h

## 2. Install into Chipyard and build (WSL Ubuntu-22.04)
    source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh
    D=~/chipyard/generators/gemmini/software/gemmini-rocc-tests
    R=/mnt/c/Users/braed/gemmini-nvfp4
    cp $R/hw/tests/nvfp4_v0.c $R/hw/tests/nvfp4_v0_data.h $D/bareMetalC/
    # one-time: add "nvfp4_v0 \" after the "template \" line in the `tests` list of $D/bareMetalC/Makefile
    touch $D/bareMetalC/nvfp4_v0.c     # the Makefile does not track the data header
    cd $D/build && make -j8 BAREMETAL_ONLY=1 bareMetalC
    # result: $D/build/bareMetalC/nvfp4_v0-baremetal
(`logs/m4-build.sh` does the copy, the Makefile edit and the build.)

## 3. Spike (functional, seconds)
    spike --extension=gemmini $D/build/bareMetalC/nvfp4_v0-baremetal
Expect `0 mismatches` on both checks and exit 0.

## 4. Verilator (cycle-accurate; sim speed ~4k cycles/s)
    cd ~/chipyard/sims/verilator
    make CONFIG=GemminiRocketConfig TIMEOUT_CYCLES=20000000 run-binary-fast \
         BINARY=$D/build/bareMetalC/nvfp4_v0-baremetal
(`logs/m4-verilator.sh` runs this under nohup and writes `~/nvfp4-logs/m4-verilator.{log,done}`.)

## Negative control
Flip one `isum` value (or one `out_bits` bit) in the installed `nvfp4_v0_data.h`, `touch` the .c file,
rebuild, and rerun: exactly 1 mismatch is reported and the exit code is 1 (`logs/m4-neg.sh`). Restore the header afterwards.

## Notes
- Gemmini's default mvout clips to int8. The test reads the accumulator with the full-width path
  (`gemmini_config_st(DIM*sizeof(acc_t))`, read address bit `ADDR_LEN-3` set), so block sums beyond +-127 survive.
- The Makefile builds with `-ffast-math`; the test keeps every float32 operation separate via `volatile`
  so the CPU result is the IEEE round-to-nearest-even sequence the reference model uses.
