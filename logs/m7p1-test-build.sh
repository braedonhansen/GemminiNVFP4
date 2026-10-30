# usage: m7p1-test-build.sh <job>
# Builds the job's workload test (base + control variant) with the rocc-tests bareMetalC compile line (as logs/m7a-build.sh / m7p-test-build.sh), outputs in
# ~/nvfp4-logs/m7p1/<job>/test. No tree file is edited: when the job's gemmini_params.h is not the tree's own, a private include root is built
# (copy of the tree's include/ with that params header) and put first on the include path.
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m7p1-env.sh
m7p1_design $1 || exit 2
case $JOB in int8-stock-b|fp32-stock-a) RTREE=$HOME/chipyard ;; *) RTREE=$HOME/chipyard-mx ;; esac
m7p1_shell $RTREE
T=$W/test
rm -rf $T; mkdir -p $T/bin $T/src $T/inc/include
RTS=$RTREE/generators/gemmini/software/gemmini-rocc-tests
cp $R/hw/tests/${TEST}.c $R/hw/tests/m7p1_mx.c $R/hw/tests/m7p1_*_data.h $T/src/ 2>/dev/null
if [ "$PARAMS" = tree ]; then
  PRIV=""; echo "params: the tree's own include/gemmini_params.h ($(md5sum $RTS/include/gemmini_params.h | cut -c1-12))"
else
  [ -s "$PARAMS" ] || { echo "FAIL: missing params header $PARAMS"; exit 2; }
  cp $RTS/include/*.h $T/inc/include/; cp $PARAMS $T/inc/include/gemmini_params.h
  # the NVFP4 params header declares acc_t as uint128_t, which no header defines for the RISC-V target: add the typedef (acc_t is not used by the test)
  if grep -q uint128_t $T/inc/include/gemmini_params.h; then awk '{print} /^#include <limits.h>/{print "typedef unsigned __int128 uint128_t;"}' $T/inc/include/gemmini_params.h > $T/p.h && mv $T/p.h $T/inc/include/gemmini_params.h; fi
  PRIV="-I$T/inc"; echo "params: $PARAMS ($(md5sum $PARAMS | cut -c1-12)) as a private include root"
fi
BENCH=$RTS/riscv-tests/benchmarks/common
grep -E "^#define (DIM|BANK_NUM|BANK_ROWS|ACC_ROWS)\b" ${PRIV:+$T/inc/}${PRIV:+include/}${PRIV:-$RTS/include/}gemmini_params.h 2>/dev/null | tr '\n' ' '; echo
for V in "base:" "ctl:-DM7P1_CTL"; do
  N=${V%%:*}; D=${V#*:}
  riscv64-unknown-elf-gcc $PRIV -DPREALLOCATE=1 -DMULTITHREAD=1 -mcmodel=medany -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf \
    -fno-tree-loop-distribute-patterns -march=rv64gc -Wa,-march=rv64gc -lm -lgcc \
    -I$T/src -I$RTS/riscv-tests -I$RTS/riscv-tests/env -I$RTS -I$BENCH -DID_STRING= -DPRINT_TILE=0 $D \
    -nostdlib -nostartfiles -static -T $BENCH/test.ld -DBAREMETAL=1 $T/src/$TEST.c -o $T/bin/${TEST}_$N $BENCH/*.c $BENCH/*.S -lm 2>&1 | head -30
  ls -la $T/bin/${TEST}_$N
done
