# usage: m7p-sim-run.sh <binary> <tag> [extra plusargs...]   -- runs the out-of-tree debug sim; log in ~/nvfp4-logs/m7p/runs/<tag>.log
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null 2>&1
BIN=$1; TAG=$2; shift 2
BIN=${BIN/#\~/$HOME}   # callers pass ~ literally (git-bash would expand it to a Windows path)
[ -f "$BIN" ] || { echo "no such binary: $BIN"; exit 2; }
G=$HOME/chipyard/sims/verilator/generated-src/chipyard.harness.TestHarness.GemminiRocketConfig
mkdir -p ~/nvfp4-logs/m7p/runs; cd ~/nvfp4-logs/m7p/runs
/usr/bin/time -v stdbuf -oL ~/nvfp4-logs/m7p/sim/simulator-gemmini-debug +permissive +dramsim +dramsim_ini_dir=$HOME/chipyard/generators/testchipip/src/main/resources/dramsim2_ini +max-cycles=60000000 +loadmem=$BIN "$@" +permissive-off $BIN </dev/null > $TAG.log 2> $TAG.err
echo "exit=$?"; tail -5 $TAG.log; grep -E "Elapsed|Maximum res" $TAG.err
