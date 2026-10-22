source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
RT=~/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests
cd $RT
ls build_spike/bareMetalC | grep -E "fp4_64x64-baremetal|fp8_64x64-baremetal|nvfp4_e2e-baremetal"
for t in matmul_tiled_fp4_64x64 matmul_tiled_fp8_64x64; do
 timeout 900 spike --extension=gemmini build_spike/bareMetalC/$t-baremetal > ~/nvfp4-logs/m7a/a0-mx-$t.log 2>&1; echo "MX $t rc=$?"; tail -3 ~/nvfp4-logs/m7a/a0-mx-$t.log
done
timeout 900 spike --extension=gemmini_nvfp4 build_spike/bareMetalC/nvfp4_e2e-baremetal > ~/nvfp4-logs/m7a/a0-nv.log 2>&1; echo "NV rc=$?"; grep -E "mismatches of" ~/nvfp4-logs/m7a/a0-nv.log
# stock
cd ~/chipyard; source env.sh
ST=~/chipyard/generators/gemmini/software/gemmini-rocc-tests
cd $ST; ls build/bareMetalC 2>/dev/null| head -3; ls build_spike 2>/dev/null | head -3; which spike; ls $RISCV/lib | grep -i gemmini
