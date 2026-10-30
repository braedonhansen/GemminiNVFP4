#!/bin/bash
# usage: [CLK_NS=5.0] [STAGE_ONLY=1] m7p1-pack.sh <job>     builds ~/nvfp4-logs/m7p1/jobs/<job>.tar.gz for the school Cadence server (no network access here).
# Generalised from logs/m7p-pack.sh. Job contents:
#   rtl/ + filelist.f          the design RTL reachable from Gemmini (unmodified gen-collateral)           (extract)
#   wrappers/                  ONE folder: the design's SRAM wrapper modules (mem_ext ... built from OpenRAM banks)
#   lib/nangate45, lib/banks   Nangate45 typical .lib and the *_pj.lib of exactly the banks this design uses
#   genus_gemmini.tcl joules_gemmini.tcl run.csh   the generalised flow (hw/power)
#   window.csh                 every per-job parameter: design, top, libraries, wrapper dir, macro/bank counts, VCD scope and window, clock
#   groups.tcl macro_instances.txt extract.json   hierarchy groups, SRAM instances, extraction facts
#   act/kernel.vcd.gz          Gemmini-scope waveform of the kernel window, timestamps rescaled so the Gemmini clock period = CLK_NS
#   MANIFEST                   sha256 of every file
# Job int8-stock-a (regeneration check, M7.P1.1): uses the M7.P0 artifacts in ~/nvfp4-logs/m7p (stub mode: OSU library, black-box stubs) and writes
# the tarball int8-stock-a-regen.
set -e
JOB=$1; [ -n "$JOB" ] || { echo "usage: $0 <job>"; exit 2; }
CLK_NS=${CLK_NS:-5.0}
CLK_PS=$(python3 -c "print(int(round($CLK_NS*1000)))")
R=/mnt/c/Users/braed/gemmini-nvfp4
L=$R/logs
K=$R/hw/power/lib/freepdk45
M1=$HOME/nvfp4-logs/m7p1
if [ "$JOB" = int8-stock-a ]; then
  SRC=$HOME/nvfp4-logs/m7p/int8; ACT=$HOME/nvfp4-logs/m7p/act; INST=gemmini; OUTNAME=int8-stock-a-regen; MODE=stub
else
  SRC=$M1/$JOB; ACT=$M1/$JOB/act; INST=$(cat $SRC/gemmini_inst.txt); OUTNAME=$JOB; MODE=wrap
fi
ROOT=TOP.TestDriver.testHarness.chiptop0.system.tile_prci_domain.element_reset_domain_rockettile.$INST
S=$M1/jobs/$OUTNAME.stage
rm -rf $S; mkdir -p $S/act $M1/jobs
need() { [ -s "$1" ] || { echo "PACK-FAIL missing or empty: $1"; exit 3; }; }
need $SRC/filelist.f; need $SRC/macro_instances.txt; need $ACT/kernel.vcd; need $ACT/clock_period_ps.txt; need $ACT/window.txt; need $ACT/window.csh
need $R/hw/power/genus_gemmini.tcl; need $R/hw/power/joules_gemmini.tcl; need $R/hw/power/run.csh
cp -r $SRC/rtl $S/rtl; cp $SRC/filelist.f $SRC/macro_instances.txt $S/
cp $R/hw/power/genus_gemmini.tcl $R/hw/power/joules_gemmini.tcl $R/hw/power/run.csh $S/
cp $ACT/window.txt $S/act/window_sim_cycles.txt
VSZ=$(stat -c %s $ACT/kernel.vcd)
# Rescale time: the simulated Gemmini clock is $SIM_PS ps (tile clock = TestDriver clock / 2); the synthesis SDC period is $CLK_PS ps.
SIM_PS=$(cat $ACT/clock_period_ps.txt)
python3 $L/m7p-vcdscale.py $ACT/kernel.vcd $S/act/kernel.vcd $CLK_PS $SIM_PS
python3 $L/m7p-vcdcheck.py $S/act/kernel.vcd $ROOT $S/act | tee $S/act/vcdcheck.txt | tail -8
grep -q "VCDCHECK PASS" $S/act/vcdcheck.txt || { echo "PACK-FAIL scaled VCD failed its check"; exit 3; }
[ "$(cat $S/act/clock_period_ps.txt)" = "$CLK_PS" ] || { echo "PACK-FAIL scaled clock period != $CLK_PS"; exit 3; }
NFILES=$(ls $S/rtl | wc -l); NLIST=$(wc -l < $SRC/filelist.f)
[ "$NFILES" -ge 100 ] || { echo "PACK-FAIL rtl has only $NFILES files"; exit 3; }
mv $S/act/window.csh $S/window.csh.base
{
  echo "# per-job parameters (M7.P1), sourced by run.csh; DUT, WIN_START_PS, WIN_END_PS come from the VCD check"
  echo "setenv DESIGN $OUTNAME"
  echo "setenv TOP Gemmini"
  cat $S/window.csh.base
  echo "setenv CLK_NS $CLK_NS"
  echo "setenv MIN_FILES $NLIST"
} > $S/window.csh
rm $S/window.csh.base
if [ "$MODE" = wrap ]; then
  need $SRC/extract.json; need $SRC/groups.tcl
  mkdir -p $S/wrappers $S/lib/nangate45 $S/lib/banks
  cp $SRC/wrappers/*.v $S/wrappers/; cp $SRC/groups.tcl $SRC/extract.json $S/
  cp $K/nangate45/NangateOpenCellLibrary_typical.lib $S/lib/nangate45/
  python3 - "$S" "$K" <<'PY'
import json, sys, shutil
s, k = sys.argv[1:3]
e = json.load(open(s + "/extract.json"))
banks = sorted(e["bank_total"])
for b in banks:
    shutil.copy("%s/openram/banks/%s_pj.lib" % (k, b), "%s/lib/banks/%s_pj.lib" % (s, b))
libs = ["$JOBDIR/lib/nangate45/NangateOpenCellLibrary_typical.lib"] + ["$JOBDIR/lib/banks/%s_pj.lib" % b for b in banks]
n_macro = sum(e["per_ext"].values())
with open(s + "/window.csh", "a") as w:
    w.write('setenv LIB_PATH "%s"\n' % " ".join(libs))
    w.write('setenv WRAPPER_DIR "$JOBDIR/wrappers"\n')
    w.write('setenv MACRO_MODS "%s"\n' % " ".join(sorted(e["per_ext"])))
    w.write('setenv EXPECT_MACRO_INSTS %d\n' % n_macro)
    w.write('setenv BANK_MODS "%s"\n' % " ".join(banks))
    w.write('setenv EXPECT_BANKS "%s"\n' % " ".join("%s=%d" % (b, e["bank_total"][b]) for b in banks))
    w.write('setenv GROUPS_TCL "$JOBDIR/groups.tcl"\n')
print("window.csh: libs %d, macro modules %s, macro instances %d, bank cells %s" % (len(libs), sorted(e["per_ext"]), n_macro, e["bank_total"]))
PY
fi
echo "--- window.csh"; cat $S/window.csh
gzip -6 $S/act/kernel.vcd            # run.csh gunzips on the server, so the question of which compressed formats Joules reads never arises
( cd $S; find . -type f ! -name MANIFEST | sort | xargs sha256sum ) > $S/MANIFEST
echo "manifest entries: $(wc -l < $S/MANIFEST)"
if [ -n "$STAGE_ONLY" ]; then echo "STAGE-ONLY: $S"; exit 0; fi
OUT=$M1/jobs/$OUTNAME.tar.gz
tar -C $S -czf $OUT .
SZ=$(stat -c %s $OUT)
echo "tarball: $OUT"
echo "size: $SZ bytes ($((SZ/1024/1024)) MiB); vcd raw $VSZ bytes shipped as kernel.vcd.gz; rtl files $NFILES; clock $CLK_NS ns"
tar tzf $OUT | grep -v '^./rtl/' | sort
echo "(+ $(tar tzf $OUT | grep -c '^./rtl/[^/]') files under rtl/)"
for f in genus_gemmini.tcl joules_gemmini.tcl run.csh filelist.f window.csh MANIFEST act/kernel.vcd.gz; do tar tzf $OUT | grep -q "^./$f$" || { echo "PACK-FAIL $f not in tarball"; exit 4; }; done
if [ $SZ -gt 1000000000 ]; then echo "PACK-WARN tarball over 1 GB: shrink the VCD window"; exit 5; fi
echo "PACK-OK"
