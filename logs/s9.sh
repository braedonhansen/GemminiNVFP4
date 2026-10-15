cd ~/chipyard
sed -n 355,372p build.sbt
grep -rn "gemmini" generators/chipyard/src/main/scala/*.scala 2>/dev/null | head -5
ls -la generators/chipyard/src/main/scala/ | head -30
cd generators/gemmini
git show origin/gemmini-mx-cleanup:.github/scripts/defaults.sh | head -90
git show origin/gemmini-mx-cleanup:.github/scripts/run-tests-mx.sh
