# Baseline of the MX Verilog generated from the branch BEFORE M6.3C changes (commit ee5991cd, generated 04:26): per-file sha256 of gen-collateral/*.sv.
N=chipyard.harness.TestHarness.MxFp4OnlyGemminiRocketConfig
D=~/chipyard-mx/sims/verilator/generated-src/$N/gen-collateral
rm -rf ~/nvfp4-logs/m6.3c-mxbase; mkdir -p ~/nvfp4-logs/m6.3c-mxbase/gen
cp $D/*.sv ~/nvfp4-logs/m6.3c-mxbase/gen/
cd ~/nvfp4-logs/m6.3c-mxbase/gen && ls | wc -l
ls | sort | xargs sha256sum > ../mx-before.sha
wc -l ../mx-before.sha; du -sh ..
