cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git grep -n -E "class .*Config|object .*Config" $B -- '*.scala' | grep -i -E "mx|fp4|fp8|fp6|vpu|radiance" | head -100
echo ----; git show $B:chipyard/GemminiConfigs.scala | head -120
