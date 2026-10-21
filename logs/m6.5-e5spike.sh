source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $RT/build_spike/bareMetalC
ls | grep -E "fp4_(64x64|128x128)" | grep baremetal
echo "installed libs: $(md5sum $RISCV/lib/libgemmini*.so | cut -c1-12 | tr '\n' ' ')"
for t in matmul_tiled_fp4_64x64 matmul_tiled_fp4_128x128 matmul_tiled_fp4_64x64_requant matmul_tiled_fp4_128x128_requant; do
  [ -x $t-baremetal ] || { echo "$t: MISSING"; continue; }
  timeout 900 spike --extension=gemmini $t-baremetal > ~/nvfp4-logs/m6.5-e5-$t.spike.log 2>&1; rc=$?
  echo "$t spike rc=$rc: $(grep -cE 'PASSED' ~/nvfp4-logs/m6.5-e5-$t.spike.log) PASSED lines, $(grep -ciE 'FAILED|mismatch' ~/nvfp4-logs/m6.5-e5-$t.spike.log) FAILED/mismatch lines"
done
echo "-- also the 3 original nvfp4 e2e in spike_nvfp4 with the (unchanged) rebuilt binaries"
cd $RT
for n in nvfp4_e2e nvfp4_e2e_s2 nvfp4_e2e_s3; do spike --extension=gemmini_nvfp4 build_spike/bareMetalC/$n-baremetal 2>&1 | grep "mismatches of"; done
