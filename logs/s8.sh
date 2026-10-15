cd ~/chipyard
grep -rn "gemmini/chipyard\|gemmini\"" build.sbt generators/chipyard/*.sbt scripts/*.sh 2>/dev/null | head
find generators/chipyard -maxdepth 6 -iname "*gemmini*" | head
cd generators/gemmini
git ls-tree -r 8c3f9923 --name-only chipyard
git show origin/gemmini-mx-cleanup:.github/scripts/do-rtl-build-mx.sh
git show origin/gemmini-mx-cleanup:.github/scripts/install-gemmini.sh
