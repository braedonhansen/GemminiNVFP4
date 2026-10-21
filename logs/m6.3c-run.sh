# usage: m6.3c-run.sh <tag>  -- run nvfp4_e2e-baremetal on the NVFP4 simulator (Verilator)
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
L=~/nvfp4-logs; TAG=${1:-run}
cd sims/verilator
S=$(date +%s)
make CONFIG=NvFp4GemminiRocketConfig run-binary LOADMEM=1 TIMEOUT_CYCLES=200000000 BINARY=$HOME/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests/build_mx_rocket/bareMetalC/nvfp4_e2e-baremetal > $L/m6.3c-$TAG.log 2>&1
echo "rc=$? secs=$(( $(date +%s) - S ))"
grep -E "nvfp4_e2e|MISMATCH|factor|Assertion|assert|PASSED|FAILED|\*\*\*" $L/m6.3c-$TAG.log | head -40 | cut -c1-250
