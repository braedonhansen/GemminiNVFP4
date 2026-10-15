cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git show $B:src/main/scala/gemmini/ScaleFactorMem.scala | sed -n 1,120p
