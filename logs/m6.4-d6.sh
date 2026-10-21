source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $RT/build_spike/bareMetalC
echo "== default libgemmini.so (installed: $(md5sum < $RISCV/lib/libgemmini.so | cut -c1-12)) vs pre-M6.4 library (md5 $(md5sum < ~/nvfp4-logs/libgemmini.base.so | cut -c1-12))"
for t in matmul_tiled_fp4_64x64 matmul_tiled_fp4_64x64_requant matmul_tiled_fp4_128x128_requant matmul_tiled_fp4_64x64_chain matmul_tiled_fp4_64x64_DRAMMvout; do
  spike --extension=gemmini $t-baremetal > ~/nvfp4-logs/m6.4-d6-$t.new.log 2>&1; rn=$?
  spike --extlib=$HOME/nvfp4-logs/libgemmini.base.so --extension=gemmini $t-baremetal > ~/nvfp4-logs/m6.4-d6-$t.base.log 2>&1; rb=$?
  echo "$t: new rc=$rn [$(grep -E 'PASSED|FAILED|mismatch' ~/nvfp4-logs/m6.4-d6-$t.new.log | head -1)]  base rc=$rb  logs_identical=$(cmp -s ~/nvfp4-logs/m6.4-d6-$t.new.log ~/nvfp4-logs/m6.4-d6-$t.base.log && echo yes || echo no)"
done
t=matmul_tiled_fp4_64x64_requant_dim32; spike --extension=gemmini_dim32 $t-baremetal 2>&1 | grep -E "PASSED|FAILED" | head -1
echo "== preprocessed gemmini.cc, default + DIM=32 + DIM=8, vs the pre-M6.4 source (assert line numbers normalised)"
W=~/nvfp4-logs/bsrc/libgemmini
for D in "" "-DGEMMINI_DIM=32" "-DGEMMINI_DIM=8"; do
  (cd $W && g++ -E -P $D -std=c++17 -I $RISCV/include gemmini.cc 2>/dev/null | sed 's/"gemmini.cc", [0-9]*/"gemmini.cc", N/' > /tmp/pp_base.txt)
  (cd $LG && g++ -E -P $D -std=c++17 -I $RISCV/include gemmini.cc 2>/dev/null | sed 's/"gemmini.cc", [0-9]*/"gemmini.cc", N/' > /tmp/pp_new.txt)
  echo "variant '$D': $(wc -l < /tmp/pp_new.txt) lines, $(cmp -s /tmp/pp_base.txt /tmp/pp_new.txt && echo IDENTICAL || echo DIFFERENT)"
done
