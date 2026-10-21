# C4: MX regression from the branch: rebuild the MX simulator (Verilator), rebuild the 64x64 FP4 test binaries, run Spike + Verilator.
R=/mnt/c/Users/braed/gemmini-nvfp4; L=~/nvfp4-logs
bash $R/logs/m6.3b-build.sh MxFp4OnlyGemminiRocketConfig c4mx | head -2 | cut -c1-200
bash $R/logs/m6.3b-b5.sh
echo c4-finished > $L/m6.3c-c4.done
