cd ~/chipyard
grep -n "freshProject\|withInitCheck" build.sbt | head -5
sed -n 105,135p build.sbt | head -5
echo ---graphics build.sbt mxgen
curl -s https://raw.githubusercontent.com/ucb-bar/chipyard/graphics/build.sbt | grep -n -i -E "mxgen|gemmini|radiance|chisel.*Version =|USE_CHISEL7" | head -30
curl -s https://raw.githubusercontent.com/ucb-bar/chipyard/graphics/.gitmodules | grep -A2 -i -E "mxgen|radiance" 
curl -s https://api.github.com/repos/ucb-bar/chipyard/branches/graphics | grep -E '"date"|"message"' | head -3
