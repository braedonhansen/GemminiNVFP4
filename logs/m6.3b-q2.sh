cd ~/nvfp4-logs
for t in nv1 mx1 nvb; do echo $t $(( $(cat m6.3b-$t.end) - $(cat m6.3b-$t.start) ))s; done
ls -la ~/chipyard-mx/sims/verilator/simulator-*
git -C ~/chipyard-mx status --short | head
