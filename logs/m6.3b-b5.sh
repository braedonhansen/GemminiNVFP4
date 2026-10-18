# B5: MX FP4 regression from the nvfp4 branch: rebuild the 64x64 FP4 test binaries (params header may have changed), run Spike and Verilator.
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
L=~/nvfp4-logs; T=matmul_tiled_fp4_64x64
cd generators/gemmini/software/gemmini-rocc-tests
rm -f build_spike/bareMetalC/$T-baremetal build_mx_rocket/bareMetalC/$T-baremetal
./build_spike.sh > $L/m6.3b-b5-spikebuild.log 2>&1; echo spike_build=$?
./build_mx_rocket.sh bareMetalC > $L/m6.3b-b5-rocketbuild.log 2>&1; echo rocket_build=$?
ls -la build_spike/bareMetalC/$T-baremetal build_mx_rocket/bareMetalC/$T-baremetal
cd build_spike/bareMetalC
timeout 900 spike --extension=gemmini ./$T-baremetal > $L/m6.3b-b5-spike.log 2>&1; echo spike_rc=$?; tail -3 $L/m6.3b-b5-spike.log
cd ~/chipyard-mx/sims/verilator
S=$(date +%s)
make CONFIG=MxFp4OnlyGemminiRocketConfig run-binary LOADMEM=1 TIMEOUT_CYCLES=200000000 BINARY=$HOME/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests/build_mx_rocket/bareMetalC/$T-baremetal > $L/m6.3b-b5-verilator.log 2>&1
echo verilator_rc=$? secs=$(( $(date +%s) - S ))
grep -E "PASSED|FAILED|MISMATCH|cycles|Assertion|assert" $L/m6.3b-b5-verilator.log | head
