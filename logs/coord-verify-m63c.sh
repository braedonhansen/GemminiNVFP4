# Coordinator check for M6.3C
G=~/chipyard-mx/generators/gemmini
echo "== branch"; git -C $G log --oneline -4 nvfp4; git -C $G status --short | head -4
R=/mnt/c/Users/braed/gemmini-nvfp4
cmp $R/hw/tests/nvfp4_e2e_data.h $G/software/gemmini-rocc-tests/bareMetalC/nvfp4_e2e_data.h && echo "installed header == repo header"
bash $R/logs/m6.3a-s7.sh coordC >/dev/null 2>&1; echo "== suite: $(cat ~/nvfp4-logs/m6.3a-work/s7_coordC.done) $(grep -E 'Tests:' ~/nvfp4-logs/m6.3a-work/s7_coordC.log)"
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh >/dev/null 2>&1
B=$(find $G/software/gemmini-rocc-tests -name 'nvfp4_e2e-baremetal' -path '*mx_rocket*' | head -1); echo "binary: $B"
cd sims/verilator; make CONFIG=NvFp4GemminiRocketConfig LOADMEM=1 TIMEOUT_CYCLES=200000000 run-binary BINARY=$B > ~/nvfp4-logs/coord-m63c-e2e.log 2>&1
echo "== e2e verilator rc=$?"; grep -E -i "mismatch|cycles|PASSED|FAILED" ~/nvfp4-logs/coord-m63c-e2e.log | tail -4
spike --extension=gemmini $G/software/gemmini-rocc-tests/build_spike/bareMetalC/matmul_tiled_fp4_64x64-baremetal 2>&1 | grep -E "PASSED|FAILED" | sed 's/^/== MX spike: /'
