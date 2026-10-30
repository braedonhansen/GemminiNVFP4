#!/bin/bash
# usage: m7p1-elab.sh <job>    Chisel/firtool elaboration of the job's config in its private tree copy (NOT in ~/chipyard or ~/chipyard-mx), then a snapshot of the
# generated gemmini_params.h. Verifies the Gemmini sources of the tree and the generated Gemmini.sv. Log: ~/nvfp4-logs/m7p1/<job>.elab.log
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m7p1-env.sh
m7p1_design $1 || exit 2
case $TREE in $M1/*) ;; *) echo "refusing to elaborate in $TREE (only in the private copies under $M1)"; exit 3 ;; esac
m7p1_shell $TREE
LOG=$M1/$JOB.elab.log
{
echo "tree $TREE; gemmini $(git -C $TREE/generators/gemmini rev-parse HEAD) ($(git -C $TREE/generators/gemmini log -1 --format=%s | cut -c1-60)); config $CFG"
git -C $TREE/generators/gemmini diff --stat HEAD -- src chipyard | tail -2
[ -n "$FRESH_CACHE" ] && rm -f $TREE/.classpath_cache/*.jar
cd $TREE/sims/verilator
/usr/bin/time -v make CONFIG=$CFG verilog -j4
echo "make exit=$?"
} > $LOG 2>&1
echo "exit: $(grep 'make exit' $LOG)"; tail -3 $LOG | cut -c1-200
grep -E "Elapsed|Maximum res" $LOG
G=$GEN/gen-collateral
[ -s $G/Gemmini.sv ] || { echo "ELAB-FAIL no Gemmini.sv"; exit 1; }
cp $TREE/generators/gemmini/software/gemmini-rocc-tests/include/gemmini_params.h $W/gemmini_params.h
cp $TREE/generators/gemmini/software/libgemmini/gemmini_params.h $W/libgemmini_params.h 2>/dev/null
ls -la --time-style=full-iso $G/Gemmini.sv $W/gemmini_params.h
echo "ELAB-OK $JOB gemmini=$(git -C $TREE/generators/gemmini rev-parse --short HEAD) Gemmini.sv lines=$(wc -l < $G/Gemmini.sv) params md5=$(md5sum < $W/gemmini_params.h | cut -c1-12)"
