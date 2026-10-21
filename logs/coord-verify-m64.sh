# Coordinator check for M6.4
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh >/dev/null 2>&1
G=~/chipyard-mx/generators/gemmini; L=$G/software/libgemmini; T=$G/software/gemmini-rocc-tests
echo "== libgemmini branch"; git -C $L branch --show-current; git -C $L log --oneline -3; git -C $L status --short | head -3
echo "== gemmini RTL branch head"; git -C $G log --oneline -1 nvfp4
ls -la $RISCV/lib/libgemmini*.so | awk '{print $5, $9}'
echo "== unit"; U=$(find $L -maxdepth 2 -name nvfp4_unit -type f | head -1); echo "$U"; (cd $(dirname $U) && ./nvfp4_unit 2>&1 | tail -3)
for t in nvfp4_e2e nvfp4_e2e_s2 nvfp4_e2e_s3; do B=$(find $T -path '*build_spike*' -name "$t-baremetal" | head -1); echo "== spike $t ($B)"; spike --extension=gemmini_nvfp4 $B 2>&1 | grep -E "mismatch"; echo "rc=$?"; done
echo "== MX spike default lib"; spike --extension=gemmini $T/build_spike/bareMetalC/matmul_tiled_fp4_64x64-baremetal 2>&1 | grep -E "PASSED|FAILED"
B=$(find $T -path '*build_mx_rocket*' -name 'nvfp4_e2e_s3-baremetal' | head -1)
cd sims/verilator; make CONFIG=NvFp4GemminiRocketConfig LOADMEM=1 TIMEOUT_CYCLES=200000000 run-binary BINARY=$B > ~/nvfp4-logs/coord-m64-s3.log 2>&1
echo "== verilator s3 rc=$?"; grep -E "mismatch" ~/nvfp4-logs/coord-m64-s3.log | tail -1
