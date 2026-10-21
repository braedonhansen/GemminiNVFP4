source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
W=~/nvfp4-logs/neg; B=$RT/build_spike/bareMetalC/nvfp4_e2e-baremetal; cd $RT
echo "libs loaded:"; LD_DEBUG=files spike --extlib=$W/libgemmini_nvfp4.so --extension=gemmini_nvfp4 $B 2>&1 | grep -E "file=.*gemmini.*needed|calling init: .*gemmini" | sort -u
spike --extlib=$W/libgemmini_nvfp4.so --extension=gemmini_nvfp4 $B 2>&1 | grep -E "MISMATCH|mismatches"; echo spike_rc=${PIPESTATUS[0]}
echo "== sanity: --extlib with the installed lib"
spike --extlib=$RISCV/lib/libgemmini_nvfp4.so --extension=gemmini_nvfp4 $B 2>&1 | grep -E "MISMATCH|mismatches"; echo spike_rc=${PIPESTATUS[0]}
