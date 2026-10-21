source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
H=$RT/bareMetalC/nvfp4_e2e_data.h; B=$RT/build_spike/bareMetalC/nvfp4_e2e-baremetal
echo "== (a) flip bit 0 of out_bits[5][7]"
LN=$(( $(grep -n 'out_bits\[' $H | cut -d: -f1) + 1 + 167/8 ))
cp $H $H.orig
T=$(sed -n ${LN}p $H | grep -o '0x[0-9a-f]\{8\}u' | sed -n 8p); echo "target token $T on line $LN"
NEW=$(printf '0x%08xu' $(( ${T%u} ^ 1 )))
sed -i "${LN}s/$T/$NEW/" $H
echo "mutation applied (diff lines): $(diff $H.orig $H | grep -c '^>')  $T -> $NEW"
touch $RT/bareMetalC/nvfp4_e2e.c; rm -f $B; (cd $RT && ./build_spike.sh bareMetalC > ~/nvfp4-logs/m6.4-negbuild.log 2>&1; echo build_rc=$?)
(cd $RT && spike --extension=gemmini_nvfp4 $B 2>&1 | grep -E "MISMATCH|mismatches"; echo spike_rc=${PIPESTATUS[0]})
cp $H.orig $H; rm $H.orig; cmp $H $R/hw/tests/nvfp4_e2e_data.h && echo "header restored (identical to repo)"
touch $RT/bareMetalC/nvfp4_e2e.c; rm -f $B; (cd $RT && ./build_spike.sh bareMetalC > ~/nvfp4-logs/m6.4-negbuild2.log 2>&1; echo rebuild_rc=$?)
(cd $RT && spike --extension=gemmini_nvfp4 $B 2>&1 | grep -E "MISMATCH|mismatches"; echo spike_rc=${PIPESTATUS[0]})
echo "== (b) model with the -0 fix reverted"
W=~/nvfp4-logs/neg; rm -rf $W; mkdir -p $W/libgemmini; ln -s $RT $W/gemmini-rocc-tests
cd $LG; cp -r gemmini.cc gemmini.h gemmini_params.h gemmini_perf.cc gemmini_perf.h mx_fp_math.h nvfp4_math.h perf $W/libgemmini/
cd $W/libgemmini
echo "before: $(grep -c 'return f32_add(first ? 0u : prev, blk);' nvfp4_math.h)"
sed -i 's/return f32_add(first ? 0u : prev, blk);/return first ? blk : f32_add(prev, blk);/' nvfp4_math.h
echo "mutation applied: $(grep -c 'return first ? blk : f32_add(prev, blk);' nvfp4_math.h)"
g++ -DGEMMINI_NVFP4 -ffp-contract=off -shared -o $W/libgemmini_nvfp4.so -std=c++17 -I $RISCV/include -fPIC -O3 gemmini.cc gemmini_perf.cc $(ls perf/*.cc perf/*/*.cc) 2>/dev/null; echo gcc_rc=$?
cd $RT
LD_LIBRARY_PATH=$W LD_DEBUG=libs spike --extension=gemmini_nvfp4 $B 2>&1 | grep -E "gemmini_nvfp4.so" | head -2
LD_LIBRARY_PATH=$W spike --extension=gemmini_nvfp4 $B 2>&1 | grep -E "MISMATCH|mismatches"; echo spike_rc=${PIPESTATUS[0]}
