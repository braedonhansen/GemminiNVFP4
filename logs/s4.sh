cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git diff 8c3f9923 $B -- src/main/scala/gemmini/GemminiConfigs.scala
ls .git/modules 2>/dev/null; ls ../../.git/modules/generators/gemmini/modules 2>/dev/null
