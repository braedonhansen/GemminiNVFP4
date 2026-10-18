source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
L=~/nvfp4-logs; T=~/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests
O=~/chipyard-mx/sims/verilator/output/chipyard.harness.TestHarness.NvFp4GemminiRocketConfig/matmul_tiled_fp4_64x64-baremetal.out
cp $O $L/m6.3b-nvnum-rtl-output.out
python3 /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3b-nvcheck.py $T/include/matmul_fp4_64x64.h $O | tee $L/m6.3b-nvnum-result.txt
echo "--- negative control (checker uses the wrong K-block for sA):"
NEG=1 python3 /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3b-nvcheck.py $T/include/matmul_fp4_64x64.h $O | tail -3 | tee $L/m6.3b-nvnum-neg.txt
