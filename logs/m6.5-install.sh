# M6.5: install the multi-tile tests into rocc-tests (untracked nvfp4_* files + the Makefile list), build Spike + rocket binaries
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $RT
for f in nvfp4_e2e_mnk.c nvfp4_mt_m64n64k128 nvfp4_mt_m32n96k64 nvfp4_mt_m96n32k256 nvfp4_mt_m64n64k512; do
  if [ "$f" = nvfp4_e2e_mnk.c ]; then cp $R/hw/tests/$f bareMetalC/; else cp $R/hw/tests/$f.c $R/hw/tests/${f}_data.h bareMetalC/; fi
done
echo "makefile mt lines: $(grep -c nvfp4_mt bareMetalC/Makefile)"; (cd bareMetalC && git diff Makefile | grep '^[+-]')
rm -f build_spike/bareMetalC/nvfp4_mt_*-baremetal build_mx_rocket/bareMetalC/nvfp4_mt_*-baremetal
./build_spike.sh bareMetalC > ~/nvfp4-logs/m6.5-spikebuild.log 2>&1; echo spikebuild_rc=$?
./build_mx_rocket.sh bareMetalC > ~/nvfp4-logs/m6.5-rocketbuild.log 2>&1; echo rocketbuild_rc=$?
ls -la build_spike/bareMetalC/nvfp4_mt_*-baremetal build_mx_rocket/bareMetalC/nvfp4_mt_*-baremetal
