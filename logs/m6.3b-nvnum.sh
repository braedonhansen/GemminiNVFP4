# Temporary numeric RTL check. Steps: (1) debug printf in AccumulatorMem (reverted at the end), (2) scratch test replaces the 64x64 FP4 test source (restored + sha-verified),
# (3) NVFP4 sim rebuild, run, compare with refmodel float32 order.
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
L=~/nvfp4-logs; G=~/chipyard-mx/generators/gemmini; T=$G/software/gemmini-rocc-tests
cp $T/bareMetalC/matmul_tiled_fp4_64x64.c $L/orig-matmul_tiled_fp4_64x64.c; sha256sum $L/orig-matmul_tiled_fp4_64x64.c > $L/orig-sha.txt
python3 - <<'PY'
p='/home/braed/chipyard-mx/generators/gemmini/src/main/scala/gemmini/AccumulatorMem.scala'
s=open(p).read()
old="    mem.io.wen := oldest_pipelined_write.valid\n"
assert s.count(old)==1
s=s.replace(old, old+'    if (use_nvfp4) { when(nvpipe.get.io.wr_valid) { printf("NVACC %x %x\n", nvpipe.get.io.wr_addr, nvpipe.get.io.wr_data.asUInt) } } // TEMP DEBUG\n')
open(p,'w').write(s)
PY
grep -n "TEMP DEBUG" $G/src/main/scala/gemmini/AccumulatorMem.scala
cp /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3b-nvtest.c $T/bareMetalC/matmul_tiled_fp4_64x64.c
cd $T && ./build_mx_rocket.sh bareMetalC > $L/m6.3b-nvnum-rocketbuild.log 2>&1; echo rocket_build=$?
cd ~/chipyard-mx/sims/verilator
make CONFIG=NvFp4GemminiRocketConfig -j8 > $L/m6.3b-nvnum-build.log 2>&1; echo sim_build=$?
S=$(date +%s)
make CONFIG=NvFp4GemminiRocketConfig run-binary LOADMEM=1 TIMEOUT_CYCLES=3000000 BINARY=$T/build_mx_rocket/bareMetalC/matmul_tiled_fp4_64x64-baremetal > $L/m6.3b-nvnum-run.log 2>&1
echo run_rc=$? secs=$(( $(date +%s) - S ))
grep -c NVACC $L/m6.3b-nvnum-run.log; grep -i -E "NVSMOKE|Assertion" $L/m6.3b-nvnum-run.log | head -3 | cut -c1-200
python3 /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3b-nvcheck.py $T/include/matmul_fp4_64x64.h $L/m6.3b-nvnum-run.log | tee $L/m6.3b-nvnum-result.txt
