cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git show $B:src/main/scala/gemmini/Arithmetic.scala | sed -n 16,60p
git show $B:src/main/scala/gemmini/Arithmetic.scala | sed -n 612,700p
