cd ~/chipyard-mx/generators/gemmini
git log --oneline -5 nvfp4; git status --short | grep -v rocc-tests
grep -c h80000000 src/main/scala/gemmini/NvFp4RmwPipe.scala
cat ~/nvfp4-logs/m6.3c-rtl0.out | cut -c1-220
ls ~/nvfp4-logs/m6.3c-rtl0.done 2>&1
ps aux | grep -E "[s]imulator-chipyard|[m]ake CONFIG|[s]bt-launch" | awk '{print $11,$12,$13,$14}' | head
