L=876631072ecc7cc8197df5dc69c4d26bd4cd5f54
R=https://raw.githubusercontent.com/ucb-bar/libgemmini/$L
curl -s $R/README.md | head -90
echo =====tree
curl -s "https://api.github.com/repos/ucb-bar/libgemmini/git/trees/$L?recursive=1" | grep '"path"' | head -40
echo ====branch containing?
curl -s "https://api.github.com/repos/ucb-bar/libgemmini/compare/$L...mxgemmini-functional-model" | grep -E '"status"|"ahead_by"|"behind_by"' | head -3
curl -s $R/Makefile | head -30
