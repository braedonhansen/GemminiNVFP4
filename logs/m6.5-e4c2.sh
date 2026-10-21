source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $RT; spike --extlib=$HOME/nvfp4-logs/neg65/libgemmini_nvfp4.so --extension=gemmini_nvfp4 build_spike/bareMetalC/nvfp4_mt_m64n64k128-baremetal 2>&1 | grep "mismatches of"
