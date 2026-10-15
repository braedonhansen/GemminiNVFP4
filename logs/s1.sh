cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git diff 8c3f9923 $B -- README.md .gitmodules src/build.sbt build.sbt | head -150
git rev-list --count $B..origin/gemmini-mx-gating; git rev-list --count origin/gemmini-mx-gating..$B
git merge-base --is-ancestor origin/gemmini-mx-gating $B && echo gating-is-ancestor
git ls-tree $B mxgen npu-exploration software/gemmini-rocc-tests software/libgemmini
