cd ~/chipyard-mx/sims/verilator/generated-src/chipyard.harness.TestHarness.NvFp4GemminiRocketConfig
ls | head -30
echo "--- module counts"
for m in NvFp4Mesh NvFp4MeshPE NvFp4PE NvFp4ScaleStage Fp32AccAdd2 Fp32AddS1 Fp32AddS2 NvFp4RmwPipe MxFpMul MxPE "module Mesh" "module Tile"; do echo "$m: $(grep -rhc "^module $m" . --include=*.sv --include=*.v 2>/dev/null | paste -sd+ | bc)"; done
echo "--- headers"
ls -la ~/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests/include/gemmini_params*.h
cd ~/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests; git status --short | head
grep -n "acc_t\|ACC_ROWS\|DIM\b" include/gemmini_params_nvfp4.h | head
