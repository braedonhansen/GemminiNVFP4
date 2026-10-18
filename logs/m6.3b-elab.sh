# usage: m6.3b-elab.sh <CONFIG> <tag>   elaborate (generate Verilog) only, no Verilator build
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
L=~/nvfp4-logs; CFG=$1; TAG=$2
rm -f $L/m6.3b-$TAG.done; date +%s > $L/m6.3b-$TAG.start
cd sims/verilator
make CONFIG=$CFG verilog > $L/m6.3b-$TAG.log 2>&1
rc=$?
date +%s > $L/m6.3b-$TAG.end
echo $rc > $L/m6.3b-$TAG.done
echo "rc=$rc secs=$(( $(cat $L/m6.3b-$TAG.end) - $(cat $L/m6.3b-$TAG.start) ))"
tail -40 $L/m6.3b-$TAG.log | cut -c1-300
