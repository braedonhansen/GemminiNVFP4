# usage: m5-s7.sh testname
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
L=~/nvfp4-logs; T=$1; rm -f $L/m5-s7-$T.done
date +%s > $L/m5-s7-$T.start
cd sims/verilator
make CONFIG=MxFp4OnlyGemminiRocketConfig run-binary LOADMEM=1 TIMEOUT_CYCLES=200000000 BINARY=$HOME/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests/build_mx_rocket/bareMetalC/$T-baremetal > $L/m5-s7-$T.log 2>&1
echo $? > $L/m5-s7-$T.rc
date +%s > $L/m5-s7-$T.end
echo done > $L/m5-s7-$T.done
