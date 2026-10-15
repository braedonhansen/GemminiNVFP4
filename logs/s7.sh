cd ~/chipyard
grep -rn -l "GemminiRocketConfig" generators/chipyard/src generators/gemmini/chipyard 2>/dev/null | head
grep -n -i gemmini build.sbt | head -20
cd generators/gemmini; git status --short | head; git log -1 --format=%H; git ls-tree 8c3f9923 chipyard | head
