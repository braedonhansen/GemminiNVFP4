source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh
cd generators/gemmini/software/gemmini-rocc-tests
sed -n 215,310p include/gemmini.h
sed -n 1,200p bareMetalC/matmul_ws.c
echo ---; spike --help 2>&1 | grep -i "extension\|extlib"; strings $(which spike) | grep -i gemmini | head; ls ~/chipyard/.conda-env/riscv-tools/lib | grep -i gemmini
find ~/chipyard -name "libgemmini*" 2>/dev/null | head
grep -n "RUNNER\|spike" ~/chipyard/generators/gemmini/README.md | head -20
grep -n "acc_t\|full_t\|ELEM\|SCALE" include/gemmini_params.h | head -60
