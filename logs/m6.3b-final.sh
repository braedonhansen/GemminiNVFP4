# Final verification pass from the committed branch state: restore temp edits, B4 (NVFP4 sim, clean build, timed), B5 (MX sim clean rebuild + tests).
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
L=~/nvfp4-logs; G=~/chipyard-mx/generators/gemmini; T=$G/software/gemmini-rocc-tests
git -C $G checkout -- src/main/scala/gemmini/AccumulatorMem.scala
grep -c "TEMP DEBUG" $G/src/main/scala/gemmini/AccumulatorMem.scala
cp $L/orig-matmul_tiled_fp4_64x64.c $T/bareMetalC/matmul_tiled_fp4_64x64.c
(cd $T/bareMetalC && sha256sum matmul_tiled_fp4_64x64.c | awk '{print $1}'; awk '{print $1}' $L/orig-sha.txt)
git -C $G status --short | grep -v rocc-tests
git -C $G log --oneline -3
(cd $T && git status --short)
echo "=== B4 final: clean NVFP4 build"
bash /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3b-clean-nv.sh > /dev/null
which time /usr/bin/time
bash /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3b-build.sh NvFp4GemminiRocketConfig nvfinal | head -3 | cut -c1-200
echo "=== B5 final: clean MX rebuild + tests"
bash /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3b-clean-mx.sh > /dev/null
bash /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3b-build.sh MxFp4OnlyGemminiRocketConfig mxfinal | head -3 | cut -c1-200
bash /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3b-b5.sh
echo "=== done"
