W=$HOME/nvfp4-logs/m6.2-work
for t in main negcarry negflip; do echo "== $t"; cat $W/t_$t.done; grep -E "RESULT|Tests:|FAILED" $W/t_$t.log | head -12; grep -c MISMATCH $W/t_$t.log; cp $W/t_$t.log /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.2-mesh-$t.log; done
