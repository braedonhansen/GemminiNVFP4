N=chipyard.harness.TestHarness.MxFp4OnlyGemminiRocketConfig
D=~/chipyard-mx/sims/verilator/generated-src/$N/gen-collateral
B=~/nvfp4-logs/m6.3c-mxbase/gen
cd ~/nvfp4-logs/m6.3c-mxbase
grep -E '\.sv$' mx-diff.txt | wc -l
for f in $(diff <(awk '{print $2" "$1}' mx-before.sha | grep '\.sv ' | sort) <(awk '{print $2" "$1}' mx-after.sha | grep '\.sv ' | sort) | grep '^[<>]' | awk '{print $2}' | sort -u); do echo "$f: before_lines=$(wc -l < $B/$f 2>/dev/null) after_lines=$(wc -l < $D/$f) difflines=$(diff $B/$f $D/$f 2>&1 | grep -c '^[<>]')"; done
echo ---
diff $B/AccumulatorScale.sv $D/AccumulatorScale.sv | head -60
