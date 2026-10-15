cd ~/chipyard/generators/gemmini
git rev-parse 266c593f
git ls-tree 266c593f mxgen software/gemmini-rocc-tests software/libgemmini npu-exploration
git log --format='%h %ad %an %s' --date=short 266c593f..origin/gemmini-mx-cleanup
git diff --stat 266c593f origin/gemmini-mx-cleanup | tail -15
git grep -n "MX_TESTS\|GemminiRocketConfig\|MxGemminiRocketConfig" origin/gemmini-mx-cleanup -- .github | head
