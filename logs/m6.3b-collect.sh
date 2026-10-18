O=/mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3b-evidence.txt; L=~/nvfp4-logs; W=$L/m6.3a-work
{
echo "== B0 tests (full standalone suite re-run, 11 tests)"; grep -E "RESULT|Tests:" $W/s7_full.log | cut -c1-250
echo "== B0 negative control (RAW stall disabled)"; grep -E "RESULT" $W/s7_b0neg.log | cut -c1-300
echo "== B0 synthesis"; cat $L/m6.3b-work/synth.csv
echo "== numeric RTL check"; cat $L/m6.3b-nvnum-result.txt; echo "-- negative control"; cat $L/m6.3b-nvnum-neg.txt
echo "== build times"; for t in nv1 mx1 nvb nvb2 nvb3 nvfinal mxb mxfinal; do [ -f $L/m6.3b-$t.end ] && echo "$t secs=$(( $(cat $L/m6.3b-$t.end) - $(cat $L/m6.3b-$t.start) )) peak_used_MB=$( [ -f $L/m6.3b-$t.mem ] && cat $L/m6.3b-$t.mem )"; done
echo "== B5 logs"; tail -3 $L/m6.3b-b5-spike.log; grep -E "PASSED|FAILED" $L/m6.3b-b5-verilator.log
echo "== branch"; git -C ~/chipyard-mx/generators/gemmini log --oneline -3 nvfp4; git -C ~/chipyard-mx/generators/gemmini status --short | grep -v rocc
} > $O 2>&1
wc -l $O
