cd ~/chipyard/sims/verilator/output/chipyard.harness.TestHarness.GemminiRocketConfig
for t in matmul conv; do
  echo "== $t  elapsed=$(( $(tail -1 ~/nvfp4-logs/long-$t.done) - $(cat ~/nvfp4-logs/long-$t.start) ))s  $(head -1 ~/nvfp4-logs/long-$t.done)"
  tail -4 ~/nvfp4-logs/long-$t.log
  grep -h -i -m5 "fail\|mismatch\|pass\|cycles" $t-baremetal.out $t-baremetal.log 2>/dev/null | head -8
done
