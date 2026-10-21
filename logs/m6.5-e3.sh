source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
rm -f ~/nvfp4-logs/m6.5-e3.done
for n in nvfp4_mt_m64n64k128 nvfp4_mt_m32n96k64 nvfp4_mt_m96n32k256 nvfp4_mt_m64n64k512; do
  echo "=== RTL $n"
  cd ~/chipyard-mx/sims/verilator
  S=$(date +%s)
  make CONFIG=NvFp4GemminiRocketConfig run-binary LOADMEM=1 TIMEOUT_CYCLES=200000000 BINARY=$RT/build_mx_rocket/bareMetalC/$n-baremetal > ~/nvfp4-logs/m6.5-rtl-$n.log 2>&1
  echo "rc=$? secs=$(( $(date +%s) - S ))"
  grep -E "mismatches of|MISMATCH|Assertion|assert|\*\*\*" ~/nvfp4-logs/m6.5-rtl-$n.log | head -12 | cut -c1-250
done
touch ~/nvfp4-logs/m6.5-e3.done
