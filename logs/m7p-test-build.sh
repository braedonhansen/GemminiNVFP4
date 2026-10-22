# usage: m7p-test-build.sh   -- builds the P0.3 workload (3 variants) with the same compile line as logs/m7a-build.sh (stock tree), outputs in ~/nvfp4-logs/m7p/test
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null 2>&1
RT=~/chipyard/generators/gemmini/software/gemmini-rocc-tests
R=/mnt/c/Users/braed/gemmini-nvfp4
W=~/nvfp4-logs/m7p/test
mkdir -p $W/bin; cp $R/hw/tests/m7p_int8_64x64x512.c $W/
BENCH=$RT/riscv-tests/benchmarks/common
for V in "base:" "full:-DM7P_FULL_REF" "corrupt:-DM7P_CORRUPT"; do
  N=${V%%:*}; D=${V#*:}
  riscv64-unknown-elf-gcc -DPREALLOCATE=1 -DMULTITHREAD=1 -mcmodel=medany -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf \
    -fno-tree-loop-distribute-patterns -march=rv64gc -Wa,-march=rv64gc -lm -lgcc \
    -I$RT/riscv-tests -I$RT/riscv-tests/env -I$RT -I$BENCH -DID_STRING= -DPRINT_TILE=0 $D \
    -nostdlib -nostartfiles -static -T $BENCH/test.ld -DBAREMETAL=1 $W/m7p_int8_64x64x512.c -o $W/bin/m7p_int8_$N $BENCH/*.c $BENCH/*.S -lm 2>&1 | head -30
  ls -la $W/bin/m7p_int8_$N
done
