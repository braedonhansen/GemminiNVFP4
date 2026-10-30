#!/bin/bash
# usage: m7p1-job.sh <job>    sim build -> workload test in RTL (base must pass) -> control (must fail) -> window + VCD -> pack -> packcheck -> mock check
# (extract + test build + spike are separate: m7p1-extract.sh, m7p1-test-build.sh, m7p1-spike.sh). Everything is logged to ~/nvfp4-logs/m7p1/<job>/job.log; one Verilator build/run at a time.
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m7p1-env.sh
m7p1_design $1 || exit 2
L=$W/job.log
{
echo "=== $(date -Iseconds) sim build"
[ -x $W/sim/simulator-debug ] && [ -z "$REBUILD" ] && echo "sim exists, skipped" || bash $R/logs/m7p1-sim-build.sh $JOB 2>&1 | tail -6
echo "=== $(date -Iseconds) RTL base run (pass 1, no dump)"
bash $R/logs/m7p1-sim-run.sh $JOB base pass1 2>&1 | tail -6
echo "=== $(date -Iseconds) RTL control run"
bash $R/logs/m7p1-sim-run.sh $JOB ctl ctl1 2>&1 | tail -4
echo "=== $(date -Iseconds) window + VCD"
bash $R/logs/m7p1-vcd.sh $JOB 2>&1 | tail -22
echo "=== $(date -Iseconds) pack"
bash $R/logs/m7p1-pack.sh $JOB 2>&1 | tail -45
echo "=== $(date -Iseconds) packcheck"
bash $R/logs/m7p1-packcheck.sh $JOB 2>&1 | tail -12
echo "=== $(date -Iseconds) tclcheck"
NEG=1 bash $R/logs/m7p1-tclcheck.sh $JOB new 2>&1 | cut -c1-230 | grep -E "^\[|M7P-FAIL|BANKS|MACRO |M7P-DONE"
echo "=== $(date -Iseconds) JOB-DONE"
} > $L 2>&1
tail -3 $L
