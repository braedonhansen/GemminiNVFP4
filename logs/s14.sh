cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git grep -n -i "npu-exploration\|npu_exploration" $B | head -15
echo ---mxgen tree
curl -s "https://api.github.com/repos/ucb-bar/MxGen/git/trees/18bdadacc67aeb755d379c177882b1e4cda13d9b?recursive=1" | grep '"path"' | head -80
