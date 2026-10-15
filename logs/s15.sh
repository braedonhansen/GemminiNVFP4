cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git show $B:build.sbt | sed -n 1,12p; git show $B:build.sbt | sed -n 36,200p
echo ---chipyard.mk; curl -s https://raw.githubusercontent.com/ucb-bar/MxGen/18bdadacc67aeb755d379c177882b1e4cda13d9b/chipyard.mk
echo ---README; curl -s https://raw.githubusercontent.com/ucb-bar/MxGen/18bdadacc67aeb755d379c177882b1e4cda13d9b/README.md | head -80
