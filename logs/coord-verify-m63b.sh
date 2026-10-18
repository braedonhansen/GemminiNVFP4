# Coordinator check for M6.3B
G=~/chipyard-mx/generators/gemmini
echo "== branch"; git -C $G branch --show-current; git -C $G log --oneline -3; git -C $G status --short | head; git -C $G merge-base --is-ancestor 266c593f nvfp4 && echo "266c593f is ancestor"
echo "== portdiff"; bash /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3b-portdiff.sh 2>&1 | tail -8
echo "== standalone suite"; bash /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3a-s7.sh coordB >/dev/null 2>&1; cat ~/nvfp4-logs/m6.3a-work/s7_coordB.done; grep -E "Tests:" ~/nvfp4-logs/m6.3a-work/s7_coordB.log
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh >/dev/null 2>&1
T=$G/software/gemmini-rocc-tests
echo "== MX spike"; spike --extension=gemmini $T/build_spike/bareMetalC/matmul_tiled_fp4_64x64-baremetal 2>&1 | grep -E "PASSED|FAILED"
echo "== sims"; ls -la sims/verilator/simulator-chipyard.harness-NvFp4GemminiRocketConfig sims/verilator/simulator-chipyard.harness-MxFp4OnlyGemminiRocketConfig | cut -c25-
cd sims/verilator; make CONFIG=MxFp4OnlyGemminiRocketConfig LOADMEM=1 TIMEOUT_CYCLES=200000000 run-binary BINARY=$T/build_mx_rocket/bareMetalC/matmul_tiled_fp4_64x64-baremetal > ~/nvfp4-logs/coord-m63b-mx.log 2>&1
echo "== MX verilator rc=$?"; grep -E "PASSED|FAILED|Completed" ~/nvfp4-logs/coord-m63b-mx.log | tail -2
