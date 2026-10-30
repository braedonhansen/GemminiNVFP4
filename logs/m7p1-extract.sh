# usage: m7p1-extract.sh <job>   -- RTL extraction + Verilator lint (with a failing control) for one job
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m7p1-env.sh
m7p1_design $1 || exit 2
m7p1_shell $TREE
for f in gemmini_params.h libgemmini_params.h; do [ -f $W/$f ] && cp $W/$f $M1/.keep.$JOB.$f; done
python3 $R/logs/m7p1-extract.py $GEN chipyard.harness.TestHarness.$CFG $WRAP $W > $M1/$JOB.extract.log 2>&1; tail -${TAILN:-25} $M1/$JOB.extract.log; cp $M1/$JOB.extract.log $W/extract.log
for f in gemmini_params.h libgemmini_params.h; do [ -f $M1/.keep.$JOB.$f ] && mv $M1/.keep.$JOB.$f $W/$f; done
grep -q "^EXTRACT-OK" $M1/$JOB.extract.log || { echo "EXTRACT-FAIL"; exit 1; }
# lint: design RTL + this design's wrappers + the OpenRAM bank models of the banks it uses (simulation models, lint only)
K=$R/hw/power/lib/freepdk45
BANKV=$(grep -o "bk_[A-Za-z0-9_]*" $W/wrappers/*.v | sed 's/.*://' | sort -u | sed "s#\(.*\)#$K/openram/banks/\1.v#" | tr '\n' ' ')
cd $W/rtl
lint() { verilator --lint-only -Wno-fatal -Wno-STMTDLY --timing --max-num-width 1048576 --top-module Gemmini "$@" 2>&1; }
lint -f ../filelist.f ../wrappers/*.v $BANKV > ../lint.log; E=$(grep -c '%Error' ../lint.log); Wn=$(grep -c '%Warning' ../lint.log)
echo "LINT full set (rtl $(wc -l < ../filelist.f) files + $(ls ../wrappers | wc -l) wrappers + $(echo $BANKV | wc -w) bank models): errors=$E warnings=$Wn"
lint -f ../filelist.f $BANKV > ../lint_nowrap.log; E2=$(grep -c '%Error' ../lint_nowrap.log)
echo "LINT control without the wrappers: errors=$E2"; grep '%Error' ../lint_nowrap.log | head -2
echo "LINT-RESULT full_errors=$E control_errors=$E2"
[ "$E" = 0 ] && [ "$E2" -gt 0 ] && echo LINT-OK || echo LINT-FAIL
