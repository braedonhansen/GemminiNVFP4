# usage: m7a-build.sh <stock|mx|fp32> <name>   -- builds ~/nvfp4-logs/m7a/src/<name>.c (copied from hw/tests) into ~/nvfp4-logs/m7a/bin/<name>
# Replicates the rocc-tests bareMetalC Makefile compile line (no tree file is edited, outputs live under ~/nvfp4-logs/m7a).
TREE=$1; NAME=$2
source ~/miniforge3/etc/profile.d/conda.sh
case $TREE in
  stock) cd ~/chipyard; source env.sh; RT=~/chipyard/generators/gemmini/software/gemmini-rocc-tests; EXTRA="" ; PRIV="";;
  mx)    cd ~/chipyard-mx; source env.sh; RT=~/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests; EXTRA="-DSPIKE_SIM"; PRIV="";;
  fp32)  cd ~/chipyard; source env.sh; RT=~/chipyard/generators/gemmini/software/gemmini-rocc-tests; EXTRA=""; PRIV="-I$HOME/nvfp4-logs/m7a/fp32inc";;
esac
R=/mnt/c/Users/braed/gemmini-nvfp4
W=~/nvfp4-logs/m7a
mkdir -p $W/src $W/bin
cp $R/hw/tests/$NAME.c $W/src/ 2>/dev/null
cp $R/hw/tests/${NAME}_data.h $W/src/ 2>/dev/null
cp $R/hw/tests/nvfp4_e2e_mnk.c $R/hw/tests/m7a_mx.c $W/src/ 2>/dev/null
for h in $R/hw/tests/${NAME}*_data.h; do cp $h $W/src/; done 2>/dev/null
BENCH=$RT/riscv-tests/benchmarks/common
riscv64-unknown-elf-gcc $PRIV -DPREALLOCATE=1 -DMULTITHREAD=1 -mcmodel=medany -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf \
  -fno-tree-loop-distribute-patterns -march=rv64gc -Wa,-march=rv64gc -lm -lgcc \
  -I$RT/riscv-tests -I$RT/riscv-tests/env -I$RT -I$BENCH -DID_STRING= -DPRINT_TILE=0 $EXTRA \
  -nostdlib -nostartfiles -static -T $BENCH/test.ld -DBAREMETAL=1 $W/src/$NAME.c -o $W/bin/$NAME $BENCH/*.c $BENCH/*.S -lm 2>&1 | head -30
ls -la $W/bin/$NAME
