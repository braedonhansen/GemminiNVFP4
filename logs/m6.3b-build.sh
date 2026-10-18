# usage: m6.3b-build.sh <CONFIG> <tag>  -- full Verilator simulator build with wall time and peak memory (used-memory sampled every 5 s)
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
L=~/nvfp4-logs; CFG=$1; TAG=$2
rm -f $L/m6.3b-$TAG.done $L/m6.3b-$TAG.mem
date +%s > $L/m6.3b-$TAG.start
( max=0; while [ ! -f $L/m6.3b-$TAG.done ]; do u=$(free -m | awk '/Mem:/{print $3}'); [ "$u" -gt "$max" ] && max=$u && echo $max > $L/m6.3b-$TAG.mem; sleep 5; done ) &
cd sims/verilator
make CONFIG=$CFG -j8 > $L/m6.3b-$TAG.log 2>&1
rc=$?
date +%s > $L/m6.3b-$TAG.end
echo $rc > $L/m6.3b-$TAG.done
echo "rc=$rc secs=$(( $(cat $L/m6.3b-$TAG.end) - $(cat $L/m6.3b-$TAG.start) )) peak_used_MB=$(cat $L/m6.3b-$TAG.mem)"
ls -la $PWD/simulator-chipyard.harness-$CFG 2>&1
tail -5 $L/m6.3b-$TAG.log | cut -c1-300
