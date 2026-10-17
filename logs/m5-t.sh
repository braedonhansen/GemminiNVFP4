cd $HOME/nvfp4-logs; T=matmul_tiled_fp4_128x128
cat m5-s7-$T.rc; echo $(( $(cat m5-s7-$T.end)-$(cat m5-s7-$T.start) ))s
grep -a "PASSED\|FAILED\|Completed" $HOME/chipyard-mx/sims/verilator/output/*/$T-baremetal.out | tail -2
cd ~/chipyard-mx; git status --short; git -C generators/gemmini submodule status | cut -c1-60; git -C generators/gemmini/software/gemmini-rocc-tests status --short
git -C ~/chipyard status --short
