source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
L=~/nvfp4-logs; G=~/chipyard-mx/generators/gemmini; T=$G/software/gemmini-rocc-tests
git -C $G checkout -- src/main/scala/gemmini/AccumulatorMem.scala
python3 /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3b-addprintf.py
grep -n -A1 "TEMP DEBUG" $G/src/main/scala/gemmini/AccumulatorMem.scala | head -3
cd ~/chipyard-mx/sims/verilator
make CONFIG=NvFp4GemminiRocketConfig -j8 > $L/m6.3b-nvnum-build.log 2>&1; echo sim_build=$?
S=$(date +%s)
make CONFIG=NvFp4GemminiRocketConfig run-binary LOADMEM=1 TIMEOUT_CYCLES=3000000 BINARY=$T/build_mx_rocket/bareMetalC/matmul_tiled_fp4_64x64-baremetal > $L/m6.3b-nvnum-run.log 2>&1
echo run_rc=$? secs=$(( $(date +%s) - S ))
grep -c NVACC $L/m6.3b-nvnum-run.log; grep -i -E "NVSMOKE|Assertion" $L/m6.3b-nvnum-run.log | head -3 | cut -c1-200
python3 /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3b-nvcheck.py $T/include/matmul_fp4_64x64.h $L/m6.3b-nvnum-run.log | tee $L/m6.3b-nvnum-result.txt
