N=chipyard.harness.TestHarness.MxFp4OnlyGemminiRocketConfig
D=~/chipyard-mx/sims/verilator/generated-src/$N/gen-collateral
B=~/nvfp4-logs/m6.3c-mxbase/gen
for f in LoopMatmulStCSpad; do
 diff <(sed -E 's@[ \t]*//.*$@@' $B/$f.sv) <(sed -E 's@[ \t]*//.*$@@' $D/$f.sv) | head -60
done
