#!/bin/tcsh -f
# run.csh -- M7.P job runner (tcsh). Started by the coordinator as:  nohup tcsh run.csh >& run.log < /dev/null &
# Runs Genus then Joules in the job directory (the directory this file is in), writes DONE or FAILED when finished.
# No ssh/scp here, nothing leaves the server.
# M7.P1: generalised from the M7.P0 runner (hw/power/p0/run.csh). The defaults below reproduce job int8-stock-a (OSU lib, SRAM stubs);
# every other job overrides them in window.csh (design, top, library list, wrapper folder, macro counts, VCD scope and window, clock).
# Fixes found on the first server run and kept: success checks match ^M7P- only (Genus echoes the script lines), SKIP_GENUS for
# Joules-only reruns, JOULES_INPUT=netlist.
cd `dirname $0`
set JOBDIR = `pwd`
rm -f DONE FAILED
mkdir -p reports out
echo "run.csh start `date`  dir=$JOBDIR host=`hostname`"

# course environment (puts Virtuoso on the path and sets the licence servers)
source ~/setup_ee477_ee577a_v2602.csh

# ---- job parameters (the same values for every design in M7: only the RTL, the macros and the activity change)
setenv DESIGN    "int8-stock-a"
setenv TOP       "Gemmini"
setenv LIB_PATH  "/tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files/gscl45nm.lib"
setenv CLK_NS    "5.0"
setenv RTL_DIR   "$JOBDIR/rtl"
setenv FILELIST  "$JOBDIR/filelist.f"
setenv OUT_DIR   "$JOBDIR/out"
setenv RPT_DIR   "$JOBDIR/reports"
setenv NCPU      "4"
setenv VCD       "$JOBDIR/act/kernel.vcd"
setenv JOULES_INPUT netlist
setenv WIN_START_PS ""
setenv WIN_END_PS ""
# kernel window (VCD time in ps), VCD scope, and the per-job overrides (DESIGN, LIB_PATH, WRAPPER_DIR, MACRO_MODS, EXPECT_MACRO_INSTS,
# BANK_MODS, EXPECT_BANKS, GROUPS_TCL ...), written by logs/m7p-pack.sh
if (-e window.csh) source window.csh
set GENUS  = /tools/cadence/DDI251/GENUS251/bin/genus
set JOULES = /tools/cadence/DDI251/JSTUDIO251/bin/joules
echo "job $DESIGN top=$TOP clk=$CLK_NS ns window=$WIN_START_PS..$WIN_END_PS"

# the VCD may be shipped gzip-compressed (see m7p-pack.sh); Joules gets the plain file
if (! -e act/kernel.vcd && -e act/kernel.vcd.gz) then
  echo "gunzip act/kernel.vcd.gz"
  gunzip -k act/kernel.vcd.gz
endif

set LIBS = ( `echo $LIB_PATH` )
foreach f ( $LIBS $GENUS $JOULES genus_gemmini.tcl joules_gemmini.tcl filelist.f act/kernel.vcd )
  if (! -e $f) then
    echo "missing input: $f"
    echo "missing input $f" > FAILED
    exit 1
  endif
end
if ($?WRAPPER_DIR) then
  if (! -d $WRAPPER_DIR) then
    echo "missing wrapper dir: $WRAPPER_DIR"
    echo "missing wrapper dir $WRAPPER_DIR" > FAILED
    exit 1
  endif
endif

# ---- 1. Genus (skipped when SKIP_GENUS is set and its outputs exist, e.g. to rerun only Joules)
if ($?SKIP_GENUS && -e out/${TOP}_netlist.v) then
echo "== Genus skipped (SKIP_GENUS set; reusing out/) `date`"
else
echo "== Genus start `date`"
$GENUS -no_gui -batch -files genus_gemmini.tcl -log reports/genus >& reports/genus.out
set rc = $status
echo "== Genus exit $rc `date`"
cp -f out/${TOP}.sdc reports/ >& /dev/null
grep "^M7P-" reports/genus.out > reports/genus.markers
if ($rc != 0 || `grep -c "^M7P-DONE" reports/genus.out` == 0 || `grep -c "^M7P-FAIL" reports/genus.out` != 0) then
  echo "Genus failed (exit $rc); see reports/genus.out" > FAILED
  grep "^M7P-FAIL\|^Error\|ERROR" reports/genus.out | head -20 >> FAILED
  exit 1
endif
endif

# ---- 2. Joules
echo "== Joules start `date`"
$JOULES -batch -files joules_gemmini.tcl -log reports/joules >& reports/joules.out
set rc = $status
echo "== Joules exit $rc `date`"
grep "^M7P-" reports/joules.out > reports/joules.markers
if ($rc != 0 || `grep -c "^M7P-DONE" reports/joules.out` == 0 || `grep -c "^M7P-FAIL" reports/joules.out` != 0) then
  echo "Joules failed (exit $rc); Genus finished; see reports/joules.out" > FAILED
  grep "^M7P-FAIL\|^Error\|ERROR" reports/joules.out | head -20 >> FAILED
  exit 1
endif

echo "ok: Genus and Joules finished" > DONE
echo "run.csh end `date`"
exit 0
