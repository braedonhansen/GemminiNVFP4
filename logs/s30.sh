cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git show $B:src/main/scala/gemmini/ScaleFactorMem.scala | sed -n 120,260p
echo ====AccumScale diff
git diff 8c3f9923 $B -- src/main/scala/gemmini/AccumulatorScale.scala | head -150
