cd ~/chipyard
grep -n -i "unmanaged\|gemmini/chipyard" build.sbt generators/chipyard/build.sbt 2>/dev/null | head
find generators/chipyard/src generators/gemmini/ -maxdepth 4 -type l 2>/dev/null | head
git status --short | head -10
cd generators/gemmini
git grep -n -i "WithMultiRoCCGemmini\|radiance\|Chisel7\|chisel7" origin/gemmini-mx-cleanup -- '*.scala' '*.sbt' '*.md' | head -30
