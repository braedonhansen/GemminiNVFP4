cd ~/chipyard
git log -1 --format=%H%n%s; git describe --tags 2>/dev/null
grep -rn -i "gemmini" generators/chipyard/src/main/scala/config/*.scala | head -20
ls generators/chipyard/src/main/scala/config | head -50
grep -n -i -E "chisel|rocketchip|scalaVersion" build.sbt | head -40
cat .gitmodules | grep -A2 -i -E "gemmini|chisel|rocket-chip" | head -30
cd generators/gemmini; git show origin/gemmini-mx-cleanup:chipyard/GemminiConfigs.scala | sed -n 120,330p | grep -n -i -E "vpu|fp4|fp6" | head -30
git log --all --oneline -S"chipyard/GemminiConfigs" -- . | head; git log origin/gemmini-mx-cleanup -3 --stat --format='%h %s' -- chipyard | head -20
