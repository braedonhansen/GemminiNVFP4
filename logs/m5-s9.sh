source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null 2>&1
echo RISCV=$RISCV; ls -l $RISCV/lib/libgemmini*.so
spike --extension=gemmini ~/chipyard/generators/gemmini/software/gemmini-rocc-tests/build/bareMetalC/nvfp4_v0-baremetal 2>&1 | tail -6; echo rc=${PIPESTATUS[0]}
git -C ~/chipyard status --short | head -3
T=matmul_tiled_fp4_128x128; cat $HOME/nvfp4-logs/m5-s7-$T.rc; echo $(( $(cat $HOME/nvfp4-logs/m5-s7-$T.end)-$(cat $HOME/nvfp4-logs/m5-s7-$T.start) ))s
grep -a "PASSED\|FAILED" $HOME/chipyard-mx/sims/verilator/output/*/$T-baremetal.out | tail -2
cd ~/chipyard-mx/generators/gemmini
grep -n "meshAccPrecisionList\|meshProdPrecisionList" -r src chipyard | cut -c1-200
