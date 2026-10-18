cd ~/nvfp4-logs
for t in nvb nvb2 nvb3 mxb; do echo "$t: Os=$(grep -c -- ' -Os ' m6.3b-$t.log) O3=$(grep -c -- ' -O3 ' m6.3b-$t.log) lines=$(wc -l < m6.3b-$t.log) secs=$(( $(cat m6.3b-$t.end) - $(cat m6.3b-$t.start) )) mem=$(cat m6.3b-$t.mem)"; done
grep -c "VTestDriver___024root__DepSet" m6.3b-nvb2.log m6.3b-nvb3.log
