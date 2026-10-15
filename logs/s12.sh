cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git show $B:build.sbt | sed -n 30,80p
echo ---- RT
git ls-remote https://github.com/Rakanic/gemmini-rocc-tests.git 2>&1 | head -20
echo ---- libgemmini
git ls-remote https://github.com/ucb-bar/libgemmini.git 2>&1 | head -30
echo ---- isa-sim
git ls-remote https://github.com/ucb-bar/esp-isa-sim.git 2>&1 | head -30
echo ---- mxgen
git ls-remote https://github.com/ucb-bar/MxGen.git 2>&1 | head
echo ---- npu
git ls-remote https://github.com/ucb-bar/npu-exploration.git 2>&1 | head -3
