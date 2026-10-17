source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh >/dev/null 2>&1
echo "gemmini: $(git -C generators/gemmini log -1 --format=%h)"
T=~/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests
echo "spike: $(which spike)"
for t in matmul_tiled_fp4_64x64 matmul_tiled_fp4_128x128x512_requant; do
  spike --extension=gemmini $T/build_spike/bareMetalC/$t-baremetal > ~/nvfp4-logs/coord-m5-$t.spike 2>&1; echo "$t spike rc=$? $(grep -o -m1 -E 'PASSED|FAILED' ~/nvfp4-logs/coord-m5-$t.spike)"
done
cd sims/verilator
make CONFIG=MxFp4OnlyGemminiRocketConfig LOADMEM=1 TIMEOUT_CYCLES=200000000 run-binary BINARY=$T/build_mx_rocket/bareMetalC/matmul_tiled_fp4_64x64-baremetal > ~/nvfp4-logs/coord-m5-verilator.log 2>&1
echo "verilator rc=$?"; grep -h -m3 -E "PASSED|FAILED|cycles" ~/nvfp4-logs/coord-m5-verilator.log output/*/matmul_tiled_fp4_64x64-baremetal.out 2>/dev/null | head -4
