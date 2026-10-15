cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git grep -n -E "MxFloat|mac_mx|MxFpMul|MxPE|MxTypeBundle" $B -- src/main/scala/gemmini/Arithmetic.scala | head -50
