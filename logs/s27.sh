C=350547f9843f46f485d4d1dd4c20b2f52f4844bf
R=https://raw.githubusercontent.com/Rakanic/gemmini-rocc-tests/$C
curl -s $R/build_mx_rocket.sh | head -60
echo =====README MX
curl -s $R/README.md | grep -n -i -B1 -A6 "mx\|fp4" | head -80
echo ====gemmini.h
curl -s $R/include/gemmini.h | grep -n -i -E "mx_|MX_|e8m0|scale_mem|SCALE" | head -50
