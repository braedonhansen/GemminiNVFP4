#!/bin/bash
# usage: [CLK_NS=5.0] m7p-pack.sh <job>   -- builds ~/nvfp4-logs/m7p/jobs/<job>.tar.gz for the USC Cadence server (no network access).
# Contents: rtl/ + filelist.f (P0.1), genus_int8.tcl, joules_int8.tcl, run.csh, act/kernel.vcd.gz (P0.3, timestamps rescaled so the
# Gemmini clock period equals CLK_NS), window.csh (window, DUT scope, CLK_NS), macro_instances.txt, MANIFEST (sha256 of every file).
set -e
JOB=$1; [ -n "$JOB" ] || { echo "usage: $0 <job>"; exit 2; }
CLK_NS=${CLK_NS:-5.0}
CLK_PS=$(python3 -c "print(int(round($CLK_NS*1000)))")
R=/mnt/c/Users/braed/gemmini-nvfp4
L=$R/logs
M=$HOME/nvfp4-logs/m7p
ROOT=TOP.TestDriver.testHarness.chiptop0.system.tile_prci_domain.element_reset_domain_rockettile.gemmini
S=$M/jobs/$JOB.stage
rm -rf $S; mkdir -p $S/act
need() { [ -s "$1" ] || { echo "PACK-FAIL missing or empty: $1"; exit 3; }; }
need $M/int8/filelist.f; need $M/int8/macro_instances.txt; need $M/act/kernel.vcd; need $M/act/clock_period_ps.txt; need $M/act/window.txt
need $R/hw/power/genus_int8.tcl; need $R/hw/power/joules_int8.tcl; need $R/hw/power/run.csh
cp -r $M/int8/rtl $S/rtl; cp $M/int8/filelist.f $M/int8/macro_instances.txt $S/
cp $R/hw/power/genus_int8.tcl $R/hw/power/joules_int8.tcl $R/hw/power/run.csh $S/
cp $M/act/window.txt $S/act/window_sim_cycles.txt
VSZ=$(stat -c %s $M/act/kernel.vcd)
# Rescale time: the simulated Gemmini clock is $SIM_PS ps (tile clock = TestDriver clock / 2); the synthesis SDC period is $CLK_PS ps.
SIM_PS=$(cat $M/act/clock_period_ps.txt)
python3 $L/m7p-vcdscale.py $M/act/kernel.vcd $S/act/kernel.vcd $CLK_PS $SIM_PS
python3 $L/m7p-vcdcheck.py $S/act/kernel.vcd $ROOT $S/act | tee $S/act/vcdcheck.txt | tail -8
grep -q "VCDCHECK PASS" $S/act/vcdcheck.txt || { echo "PACK-FAIL scaled VCD failed its check"; exit 3; }
[ "$(cat $S/act/clock_period_ps.txt)" = "$CLK_PS" ] || { echo "PACK-FAIL scaled clock period != $CLK_PS"; exit 3; }
echo "setenv CLK_NS $CLK_NS" >> $S/act/window.csh
mv $S/act/window.csh $S/window.csh
gzip -6 $S/act/kernel.vcd            # run.csh gunzips on the server, so the question of which compressed formats Joules reads never arises
NFILES=$(ls $S/rtl | wc -l)
[ "$NFILES" -ge 130 ] || { echo "PACK-FAIL rtl has only $NFILES files"; exit 3; }
( cd $S; find . -type f ! -name MANIFEST | sort | xargs sha256sum ) > $S/MANIFEST
OUT=$M/jobs/$JOB.tar.gz
tar -C $S -czf $OUT .
SZ=$(stat -c %s $OUT)
echo "tarball: $OUT"
echo "size: $SZ bytes ($((SZ/1024/1024)) MiB); vcd raw $VSZ bytes shipped as kernel.vcd.gz; rtl files $NFILES; clock $CLK_NS ns"
tar tzf $OUT | grep -v '^./rtl/' | sort
echo "(+ $(tar tzf $OUT | grep -c '^./rtl/[^/]') files under rtl/)"
for f in genus_int8.tcl joules_int8.tcl run.csh filelist.f window.csh MANIFEST act/kernel.vcd.gz; do tar tzf $OUT | grep -q "^./$f$" || { echo "PACK-FAIL $f not in tarball"; exit 4; }; done
if [ $SZ -gt 1000000000 ]; then echo "PACK-WARN tarball over 1 GB: shrink the VCD window"; exit 5; fi
echo "PACK-OK"
