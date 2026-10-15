cd ~/chipyard
sed -n 60,92p build.sbt
cd generators/gemmini
git grep -n "package mxgen\|import mxgen" origin/gemmini-mx-cleanup -- src/main | head -8
git show origin/gemmini-mx-cleanup:.gitignore | head -30
