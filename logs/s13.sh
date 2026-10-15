for r in ucb-bar/npu-exploration ucb-bar/MxGen Rakanic/gemmini-rocc-tests ucb-bar/libgemmini; do echo $r; curl -s -o /dev/null -w "%{http_code}\n" https://api.github.com/repos/$r; done
echo mxgen-commit; curl -s https://api.github.com/repos/ucb-bar/MxGen/commits/18bdadacc67aeb755d379c177882b1e4cda13d9b | grep -E '"message"|"date"|"name"' | head -4
echo libgemmini-commit; curl -s https://api.github.com/repos/ucb-bar/libgemmini/commits/876631072ecc7cc8197df5dc69c4d26bd4cd5f54 | grep -E '"message"|"date"|"name"|"message":' | head -4
curl -s "https://api.github.com/repos/ucb-bar/libgemmini/compare/master...876631072ecc7cc8197df5dc69c4d26bd4cd5f54" | grep -E '"status"|"ahead_by"|"behind_by"'
curl -s "https://api.github.com/repos/ucb-bar/libgemmini/branches?per_page=100" | grep '"name"' | head -40
curl -s "https://api.github.com/repos/ucb-bar/libgemmini/commits?sha=mxgemmini-functional-model&per_page=5" | grep -E '"sha"|"message"' | head -10
echo npu-commit; curl -s https://api.github.com/repos/ucb-bar/npu-exploration/commits/0344bcba70b899039ccd0ac0801ca5605d46d3eb | grep -E '"message"' | head -2
