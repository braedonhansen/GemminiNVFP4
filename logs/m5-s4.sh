source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
L=~/nvfp4-logs; rm -f $L/m5-s4.done $L/m5-mem.max
date +%s > $L/m5-s4.start
( max=0; while [ ! -f $L/m5-s4.done ]; do u=$(free -m | awk '/Mem:/{print $3}'); [ "$u" -gt "$max" ] && max=$u && echo $max > $L/m5-mem.max; sleep 15; done ) &
cd sims/verilator
make CONFIG=MxFp4OnlyGemminiRocketConfig -j8 > $L/m5-s4.log 2>&1
rc=$?
date +%s > $L/m5-s4.end
echo $rc > $L/m5-s4.done
