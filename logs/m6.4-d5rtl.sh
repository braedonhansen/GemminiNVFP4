source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
ls -la ~/chipyard-mx/sims/verilator/simulator-chipyard.harness-NvFp4GemminiRocketConfig
for n in nvfp4_e2e_s2 nvfp4_e2e_s3 nvfp4_e2e; do
  echo "=== RTL $n"
  cd ~/chipyard-mx/sims/verilator
  S=$(date +%s)
  make CONFIG=NvFp4GemminiRocketConfig run-binary LOADMEM=1 TIMEOUT_CYCLES=200000000 BINARY=$RT/build_mx_rocket/bareMetalC/$n-baremetal > ~/nvfp4-logs/m6.4-rtl-$n.log 2>&1
  echo "rc=$? secs=$(( $(date +%s) - S ))"
  grep -E "nvfp4_e2e|MISMATCH|Assertion|assert|\*\*\*" ~/nvfp4-logs/m6.4-rtl-$n.log | head -10 | cut -c1-250
done
touch ~/nvfp4-logs/m6.4-d5rtl.done
