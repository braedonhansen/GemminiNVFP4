source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $RT
for n in nvfp4_mt_m64n64k128 nvfp4_mt_m32n96k64 nvfp4_mt_m96n32k256 nvfp4_mt_m64n64k512; do
  timeout 900 spike --extension=gemmini_nvfp4 build_spike/bareMetalC/$n-baremetal > ~/nvfp4-logs/m6.5-spike-$n.log 2>&1; rc=$?
  echo "$n spike rc=$rc | $(grep -cE MISMATCH ~/nvfp4-logs/m6.5-spike-$n.log) mismatch lines | $(grep -E 'mismatches of' ~/nvfp4-logs/m6.5-spike-$n.log)"
  grep MISMATCH ~/nvfp4-logs/m6.5-spike-$n.log | head -8
done
