source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
echo "== (c) Spike model with the N-tile (j-group) offset of the FP32 store mutated, shape 1"
B1=$RT/build_spike/bareMetalC/nvfp4_mt_m64n64k128-baremetal
W=~/nvfp4-logs/neg65; rm -rf $W; mkdir -p $W/libgemmini; ln -s $RT $W/gemmini-rocc-tests
cd $LG; cp -r gemmini.cc gemmini.h gemmini_params.h gemmini_perf.cc gemmini_perf.h mx_fp_math.h nvfp4_math.h perf $W/libgemmini/
cd $W/libgemmini
echo "before: $(grep -c 'const size_t e = (size_t)r \* N_DIM + c;' gemmini.cc)"
sed -i 's/const size_t e = (size_t)r \* N_DIM + c;/const size_t e = (size_t)r * N_DIM + (c + 32) % N_DIM;/' gemmini.cc
echo "mutation applied: $(grep -c '(c + 32) % N_DIM;' gemmini.cc)"
g++ -DGEMMINI_NVFP4 -ffp-contract=off -shared -o $W/libgemmini_nvfp4.so -std=c++17 -I $RISCV/include -fPIC -O3 gemmini.cc gemmini_perf.cc $(ls perf/*.cc perf/*/*.cc) 2>$W/gcc.err; echo gcc_rc=$?
cd $RT
echo "libs loaded:"; LD_DEBUG=files spike --extlib=$W/libgemmini_nvfp4.so --extension=gemmini_nvfp4 $B1 2>&1 | grep -E "file=.*gemmini.*needed|calling init: .*gemmini" | sort -u
spike --extlib=$W/libgemmini_nvfp4.so --extension=gemmini_nvfp4 $B1 2>&1 | grep -E "MISMATCH|mismatches" | head -4; echo spike_rc=${PIPESTATUS[0]}
echo "== sanity: unmutated installed lib, same binary"
spike --extension=gemmini_nvfp4 $B1 2>&1 | grep -E "MISMATCH|mismatches"; echo spike_rc=${PIPESTATUS[0]}
