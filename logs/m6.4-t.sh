source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $RT
spike --extension=gemmini_nvfp4 build_spike/bareMetalC/mvin_mvout-baremetal; echo rc=$?
spike --extlib=libgemmini_nvfp4.so --extension=gemmini_nvfp4 build_spike/bareMetalC/nvfp4_e2e-baremetal 2>&1 | head; echo rc=${PIPESTATUS[0]}
spike --help 2>&1 | grep -i ext
