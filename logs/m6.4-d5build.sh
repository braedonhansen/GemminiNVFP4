source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $RT
for n in s2 s3; do cp $R/hw/tests/nvfp4_e2e_$n.c $R/hw/tests/nvfp4_e2e_${n}_data.h bareMetalC/; done

(cd bareMetalC && git diff Makefile | grep '^[+-]')
rm -f build_spike/bareMetalC/nvfp4_e2e_s?-baremetal build_mx_rocket/bareMetalC/nvfp4_e2e_s?-baremetal
./build_spike.sh bareMetalC > ~/nvfp4-logs/m6.4-d5-spikebuild.log 2>&1; echo spikebuild_rc=$?
./build_mx_rocket.sh bareMetalC > ~/nvfp4-logs/m6.4-d5-rocketbuild.log 2>&1; echo rocketbuild_rc=$?
ls -la build_spike/bareMetalC/nvfp4_e2e*-baremetal build_mx_rocket/bareMetalC/nvfp4_e2e*-baremetal
for n in nvfp4_e2e nvfp4_e2e_s2 nvfp4_e2e_s3; do echo "-- spike $n"; spike --extension=gemmini_nvfp4 build_spike/bareMetalC/$n-baremetal 2>&1 | grep -E "MISMATCH|mismatches"; echo rc=${PIPESTATUS[0]}; done
