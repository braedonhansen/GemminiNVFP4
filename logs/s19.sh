cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git grep -n -i "scale" $B -- src/main/scala/gemmini/Mesh.scala src/main/scala/gemmini/PE.scala src/main/scala/gemmini/Tile.scala src/main/scala/gemmini/MeshWithDelays.scala | head -60
echo ======PE diff
git diff 8c3f9923 $B -- src/main/scala/gemmini/PE.scala
