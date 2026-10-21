# Compare the MX Verilog regenerated from the branch AFTER M6.3C against the baseline taken before (per-module sha256 + module list)
N=chipyard.harness.TestHarness.MxFp4OnlyGemminiRocketConfig
D=~/chipyard-mx/sims/verilator/generated-src/$N/gen-collateral
cd $D && ls | wc -l
ls | sort | xargs sha256sum > ~/nvfp4-logs/m6.3c-mxbase/mx-after.sha
cd ~/nvfp4-logs/m6.3c-mxbase
echo "modules before: $(wc -l < mx-before.sha)  after: $(wc -l < mx-after.sha)"
diff mx-before.sha mx-after.sha > mx-diff.txt && echo "MX Verilog IDENTICAL (all $(wc -l < mx-after.sha) module files, same sha256)" || { echo "DIFFERENCES:"; head -20 mx-diff.txt; }
sha256sum mx-before.sha mx-after.sha
sha256sum ~/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests/include/gemmini_params.h; cat ~/nvfp4-logs/m6.3c-params-before.sha
