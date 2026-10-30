#!/bin/bash
# usage: [NEG=1] m7p1-tclcheck.sh <job> [new|old]    mock-shell run of the Genus and Joules scripts with the job's own parameters (M7.P1.1)
#   <job>  the job whose stage dir ~/nvfp4-logs/m7p1/jobs/<job>.stage is used (int8-stock-a: the *-regen stage)
#   new    hw/power/genus_gemmini.tcl + joules_gemmini.tcl        old   hw/power/p0/genus_int8.tcl + joules_int8.tcl (job a only)
# Prints the M7P- marker lines and the call count; the call trace of every run is ~/nvfp4-logs/m7p1/mock/<job>.<new|old>.<tag>/trace.txt.
# With NEG=1 also runs the negative controls (wrong bank/macro counts, missing library, empty wrapper dir, empty VCD, get_db attribute failing).
ARG1=$1; ARG2=$2
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m7p1-env.sh; m7p1_shell $HOME/chipyard   # tclsh comes from the tree conda env
JOB=$ARG1; WHICH=${ARG2:-new}
which tclsh >/dev/null || { echo "no tclsh"; exit 2; }
R=/mnt/c/Users/braed/gemmini-nvfp4
M1=$HOME/nvfp4-logs/m7p1
case $JOB in int8-stock-a) ST=$M1/jobs/int8-stock-a-regen.stage ;; *) ST=$M1/jobs/$JOB.stage ;; esac
[ -f $ST/window.csh ] || { echo "no stage $ST"; exit 2; }
if [ $WHICH = old ]; then G=$R/hw/power/p0/genus_int8.tcl; J=$R/hw/power/p0/joules_int8.tcl; else G=$R/hw/power/genus_gemmini.tcl; J=$R/hw/power/joules_gemmini.tcl; fi
run() {  # run <tag>: builds a fresh mock dir, runs genus then joules, echoes markers
  TAG=$1
  Wd=$M1/mock/$JOB.$WHICH.$TAG; rm -rf $Wd; mkdir -p $Wd/act $Wd/out
  (
    export JOBDIR=$ST
    # job parameters: run.csh defaults, then window.csh (setenv lines)
    export TOP=Gemmini CLK_NS=5.0 NCPU=4 RTL_DIR=$ST/rtl FILELIST=$ST/filelist.f OUT_DIR=$Wd/out RPT_DIR=$Wd/reports VCD=$Wd/act/kernel.vcd JOULES_INPUT=netlist
    export LIB_PATH="/tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files/gscl45nm.lib"
    eval "$(sed -n 's/^setenv \([A-Za-z_0-9]*\) "\(.*\)"$/export \1="\2"/p; s/^setenv \([A-Za-z_0-9]*\) \([^" ]*\)$/export \1=\2/p' $ST/window.csh | sed "s#\$JOBDIR#$ST#g")"
    # job a points at a server path: use a fake library file that exists here
    if [ ! -e "${LIB_PATH%% *}" ]; then mkdir -p $Wd/fakelib; touch $Wd/fakelib/gscl45nm.lib; export LIB_PATH=$Wd/fakelib/gscl45nm.lib; fi
    echo x > $Wd/act/kernel.vcd
    # counts the mock answers with, taken from macro_instances.txt (module in column 2, banks in column 6)
    export MOCK_MACRO_COUNTS="$(awk -F' [|] ' '{c[$2]++} END{for(k in c) printf "%s=%d ", k, c[k]}' $ST/macro_instances.txt)"
    export MOCK_BANK_COUNTS="$(awk -F' [|] ' '{n=split($6,a,","); sub(/^banks /,"",a[1]); for(i=1;i<=n;i++){split(a[i],kv,"*"); if(kv[1]!="") c[kv[1]]+=kv[2]}} END{for(k in c) printf "%s=%d ", k, c[k]}' $ST/macro_instances.txt)"
    [ -n "$WRAPPER_DIR" ] && export MOCK_WRAPPERS=$WRAPPER_DIR
    export MOCK_JOBDIR=$ST MOCK_TRACE=$Wd/trace.txt
    case $TAG in
      nodb)        export MOCK_NO_DB_BANKS=1 ;;                                            # get_db attribute fails: the netlist parse must give the same count
      neg_expect)  export EXPECT_BANKS="$(echo "$EXPECT_BANKS" | sed 's/=/=9/g')" ;;      # both counting methods disagree with the expectation
      neg_macro)   export EXPECT_MACRO_INSTS=$((EXPECT_MACRO_INSTS + 1)) ;;
      neg_lib)     export LIB_PATH="$LIB_PATH /nonexistent/x.lib" ;;
      neg_wrap)    mkdir -p $Wd/emptyw; export WRAPPER_DIR=$Wd/emptyw; unset MOCK_WRAPPERS ;;
      neg_vcd)     EMPTYVCD=1 ;;
    esac
    echo "[$TAG] design=${DESIGN:-job-a-defaults} libs=$(echo $LIB_PATH | wc -w) wrappers=${WRAPPER_DIR##*/} macros=${EXPECT_MACRO_INSTS:-6} banks=$EXPECT_BANKS; mock answers: $MOCK_MACRO_COUNTS / $MOCK_BANK_COUNTS"
    cd $Wd
    tclsh $R/logs/m7p1-tclmock.tcl $G genus > genus.out 2>&1; grc=$?
    grep -E "^M7P-|^MOCK" genus.out | sed 's/^/  G /' | cut -c1-230
    touch out/Gemmini_netlist.v out/Gemmini.sdc; echo x > act/kernel.vcd; [ -n "$EMPTYVCD" ] && : > act/kernel.vcd
    tclsh $R/logs/m7p1-tclmock.tcl $J joules > joules.out 2>&1; jrc=$?
    grep -E "^M7P-|^MOCK" joules.out | sed 's/^/  J /' | cut -c1-200
    echo "[$TAG] genus rc=$grc ($(grep -c '^M7P-DONE' genus.out) DONE, $(grep -c '^M7P-FAIL' genus.out) FAIL)  joules rc=$jrc ($(grep -c '^M7P-DONE' joules.out) DONE, $(grep -c '^M7P-FAIL' joules.out) FAIL)  calls: $(wc -l < trace.txt)"
  )
}
run normal
if [ -n "$NEG" ]; then
  run nodb | grep -E "BANKS|^\[nodb"
  echo "== negative controls (each must FAIL: M7P-FAIL and a nonzero exit, or an empty-VCD failure in Joules)"
  for t in neg_expect neg_macro neg_lib neg_wrap neg_vcd; do run $t | grep -E "M7P-FAIL|^\[$t\] genus"; done
fi
