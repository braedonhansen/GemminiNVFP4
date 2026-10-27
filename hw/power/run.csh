#!/bin/tcsh -f
# run.csh -- M7.P0 job runner (tcsh). Started by the coordinator as:  nohup tcsh run.csh >& run.log < /dev/null &
# Runs Genus then Joules in the job directory (the directory this file is in), writes DONE or FAILED when finished.
# No ssh/scp here, nothing leaves the server.
cd `dirname $0`
set JOBDIR = `pwd`
rm -f DONE FAILED
mkdir -p reports out
echo "run.csh start `date`  dir=$JOBDIR host=`hostname`"

# course environment (puts Virtuoso on the path and sets the licence servers)
source ~/setup_ee477_ee577a_v2602.csh

# ---- job parameters (the same values for every design in M7: only the RTL changes)
setenv LIB_PATH  "/tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files/gscl45nm.lib"
setenv CLK_NS    "5.0"
setenv RTL_DIR   "$JOBDIR/rtl"
setenv FILELIST  "$JOBDIR/filelist.f"
setenv OUT_DIR   "$JOBDIR/out"
setenv RPT_DIR   "$JOBDIR/reports"
setenv NCPU      "4"
setenv VCD       "$JOBDIR/act/kernel.vcd"
# kernel window (VCD time in ps) and VCD facts, written by logs/m7p-pack.sh
if (-e window.csh) source window.csh
set GENUS  = /tools/cadence/DDI251/GENUS251/bin/genus
set JOULES = /tools/cadence/DDI251/JSTUDIO251/bin/joules

# the VCD may be shipped gzip-compressed (see m7p-pack.sh); Joules gets the plain file
if (! -e act/kernel.vcd && -e act/kernel.vcd.gz) then
  echo "gunzip act/kernel.vcd.gz"
  gunzip -k act/kernel.vcd.gz
endif

foreach f ( $LIB_PATH $GENUS $JOULES genus_int8.tcl joules_int8.tcl filelist.f act/kernel.vcd )
  if (! -e $f) then
    echo "missing input: $f"
    echo "missing input $f" > FAILED
    exit 1
  endif
end

# ---- 1. Genus (skipped when SKIP_GENUS is set and its outputs exist, e.g. to rerun only Joules)
if ($?SKIP_GENUS && -e out/Gemmini_netlist.v) then
echo "== Genus skipped (SKIP_GENUS set; reusing out/) `date`"
else
echo "== Genus start `date`"
$GENUS -no_gui -batch -files genus_int8.tcl -log reports/genus >& reports/genus.out
set rc = $status
echo "== Genus exit $rc `date`"
cp -f out/Gemmini.sdc reports/ >& /dev/null
if ($rc != 0 || `grep -c "^M7P-DONE" reports/genus.out` == 0 || `grep -c "^M7P-FAIL" reports/genus.out` != 0) then
  echo "Genus failed (exit $rc); see reports/genus.out" > FAILED
  grep "^M7P-FAIL\|^Error\|ERROR" reports/genus.out | head -20 >> FAILED
  exit 1
endif
endif

# ---- 2. Joules
echo "== Joules start `date`"
$JOULES -batch -files joules_int8.tcl -log reports/joules >& reports/joules.out
set rc = $status
echo "== Joules exit $rc `date`"
if ($rc != 0 || `grep -c "^M7P-DONE" reports/joules.out` == 0 || `grep -c "^M7P-FAIL" reports/joules.out` != 0) then
  echo "Joules failed (exit $rc); Genus finished; see reports/joules.out" > FAILED
  grep "^M7P-FAIL\|^Error\|ERROR" reports/joules.out | head -20 >> FAILED
  exit 1
endif

echo "ok: Genus and Joules finished" > DONE
echo "run.csh end `date`"
exit 0
