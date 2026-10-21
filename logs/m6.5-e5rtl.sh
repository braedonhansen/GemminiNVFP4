source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd ~/chipyard-mx/sims/verilator
ls -la --time-style=full-iso simulator-chipyard.harness-MxFp4OnlyGemminiRocketConfig | cut -c30-
S=$(date +%s)
make CONFIG=MxFp4OnlyGemminiRocketConfig run-binary LOADMEM=1 TIMEOUT_CYCLES=200000000 BINARY=$RT/build_mx_rocket/bareMetalC/matmul_tiled_fp4_64x64-baremetal > ~/nvfp4-logs/m6.5-e5-rtl.log 2>&1
echo "rc=$? secs=$(( $(date +%s) - S ))"
grep -E "PASSED|FAILED|cycles|Assertion" ~/nvfp4-logs/m6.5-e5-rtl.log | head -5 | cut -c1-200
cd $G 2>/dev/null; cd ~/chipyard-mx/generators/gemmini; git status --short | grep -v software/; git log --oneline | head -1
