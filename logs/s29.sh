cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
for f in $(git ls-tree --name-only $B src/test/scala/mxHardware/ src/test/scala/gemmini/ | grep -v disabled); do echo "== $f"; git show $B:$f | grep -E "^import|extends (AnyFlatSpec|AnyFreeSpec|FlatSpec|FunSuite|AnyFunSuite)|ChiselScalatestTester|Verilator|simulator" | sort -u | head -6; done 2>/dev/null | head -120
git ls-tree --name-only $B src/test/scala/gemmini/
git show $B:src/test/scala/gemmini/TestMxFpMul.scala.disabled | head -5
