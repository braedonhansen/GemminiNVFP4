source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
make -C generators/gemmini/software/libgemmini install 2>&1 | tail -5
ls -l $RISCV/lib/libgemmini*.so
grep -rn "class .*Mx.*Config\|class .*FP4.*Config\|class .*Fp4.*Config" generators/gemmini/src generators/chipyard/src generators/gemmini/chipyard 2>/dev/null | head -20
