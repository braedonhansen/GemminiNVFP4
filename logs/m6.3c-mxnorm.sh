# MX Verilog unchanged? Compare per-module sha256 after stripping the "// @[file:line:col]" source-info comments and the Scala line
# numbers inside assertion-message text (both shift when Scala lines are inserted above them).
N=chipyard.harness.TestHarness.MxFp4OnlyGemminiRocketConfig
D=~/chipyard-mx/sims/verilator/generated-src/$N/gen-collateral
B=~/nvfp4-logs/m6.3c-mxbase/gen
cd ~/nvfp4-logs/m6.3c-mxbase
norm() { ( cd $1 && for f in $(ls *.sv | sort); do echo "$(sed -E -e 's@[ \t]*//.*$@@' -e 's@\.scala:[0-9]+@.scala:N@g' $f | sha256sum | cut -d' ' -f1)  $f"; done ); }
norm $B > mx-before.norm.sha; norm $D > mx-after.norm.sha
echo "modules before: $(wc -l < mx-before.norm.sha)  after: $(wc -l < mx-after.norm.sha)"
if diff mx-before.norm.sha mx-after.norm.sha > mx-norm-diff.txt; then echo "MX Verilog IDENTICAL after normalisation: all $(wc -l < mx-after.norm.sha) modules, same sha256"; else echo "DIFFERENT modules:"; cat mx-norm-diff.txt | head -20; fi
sha256sum mx-before.norm.sha mx-after.norm.sha
