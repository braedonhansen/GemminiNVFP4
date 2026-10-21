source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $LG; git status --short
git add nvfp4_math.h nvfp4_unit.cc gemmini.cc Makefile
git -c user.name=Braedonhansen -c user.email=braedon.hansen@gmail.com commit -q -m "NVFP4 model (-DGEMMINI_NVFP4): exact E2M1 block sums, E4M3 scale stage, FP32 accumulate, tensor factor at mvout; libgemmini_nvfp4.so + host unit check" 
git log --oneline | head -2
