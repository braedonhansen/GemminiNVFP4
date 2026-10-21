source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
W=~/nvfp4-logs/neg65; cd $W/libgemmini
ls; ls perf | head
g++ -DGEMMINI_NVFP4 -ffp-contract=off -shared -o $W/libgemmini_nvfp4.so -std=c++17 -I $RISCV/include -fPIC -O3 gemmini.cc gemmini_perf.cc 2>&1 | head -20
