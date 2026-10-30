# usage: m7p1-sim-run.sh <job> <test-binary-suffix: base|ctl> <tag> [extra plusargs...]
# Runs the job's out-of-tree debug sim on the job's test binary; log in ~/nvfp4-logs/m7p1/<job>/runs/<tag>.log (generalised from logs/m7p-sim-run.sh)
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m7p1-env.sh
m7p1_design $1 || exit 2
V=$2; TAG=$3; shift 3
m7p1_shell $TREE
BIN=$W/test/bin/${TEST}_$V
[ -f "$BIN" ] || { echo "no such binary: $BIN"; exit 2; }
mkdir -p $W/runs; cd $W/runs
/usr/bin/time -v stdbuf -oL $W/sim/simulator-debug +permissive +dramsim +dramsim_ini_dir=$TREE/generators/testchipip/src/main/resources/dramsim2_ini +max-cycles=${MAXCYC:-100000000} +loadmem=$BIN "$@" +permissive-off $BIN </dev/null > $TAG.log 2> $TAG.err
echo "exit=$?"; tail -5 $TAG.log; grep -E "Elapsed|Maximum res" $TAG.err
