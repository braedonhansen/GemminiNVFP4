# usage: m7p1-spike.sh <job> [extra spike args...]   -- quick Spike check of the job's test (base must pass, ctl must fail)
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m7p1-env.sh
m7p1_design $1 || exit 2; shift
case $JOB in int8-stock-b|fp32-stock-a) RTREE=$HOME/chipyard ;; *) RTREE=$HOME/chipyard-mx ;; esac
m7p1_shell $RTREE
for v in base ctl; do
  timeout 3000 spike "$@" $W/test/bin/${TEST}_$v > $W/test/spike_$v.log 2>&1; echo "spike $v rc=$?"; grep -E "^m7p1|outputs checked|MISMATCH|C\[" $W/test/spike_$v.log | head -5
done
