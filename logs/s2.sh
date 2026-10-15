cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git show $B:src/main/scala/gemmini/MxConfigFragments.scala | head -170
echo ======ISA
git diff 8c3f9923 $B -- src/main/scala/gemmini/GemminiISA.scala
