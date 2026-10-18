# Smoke only (NOT a pass criterion): the M5 MX FP4 64x64 test binary on the NVFP4 simulator. Results are expected to mismatch
# (E8M0 0x7f scales are E4M3 NaN, and mvout is not yet FP32-aware); the point is to see whether it finishes and whether any RTL assertion fires.
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
L=~/nvfp4-logs; T=matmul_tiled_fp4_64x64
cd sims/verilator
S=$(date +%s)
make CONFIG=NvFp4GemminiRocketConfig run-binary LOADMEM=1 TIMEOUT_CYCLES=3000000 BINARY=$HOME/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests/build_mx_rocket/bareMetalC/$T-baremetal > $L/m6.3b-smoke.log 2>&1
echo rc=$? secs=$(( $(date +%s) - S ))
grep -i -E "assert|PASSED|FAILED|MISMATCH|timeout|Completed" $L/m6.3b-smoke.log | head -10 | cut -c1-250
