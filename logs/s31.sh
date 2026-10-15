cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git grep -n -E "tilesPerMxBlock|scaleSize|scale_size" $B -- src/main | head -30
echo ---- E8M0 default 0x7e / 7f
git grep -n -i -E "e8m0|E9M0" $B -- src/main | wc -l
echo --- DIM16 ? mx default DIM  meshRows
git grep -n "useFpnewAdder" $B -- src/main | head -3
echo ---- Mesh diff
git diff 8c3f9923 $B -- src/main/scala/gemmini/Mesh.scala | head -120
