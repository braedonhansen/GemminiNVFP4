C=350547f9843f46f485d4d1dd4c20b2f52f4844bf
curl -s "https://api.github.com/repos/Rakanic/gemmini-rocc-tests/git/trees/$C?recursive=1" | grep '"path"' | grep -i -E "mx|fp4|fp8|fp6|bareMetalC/matmul_tiled|mlps|scripts|\.py|build_spike|Makefile|build.sh|gemmini.h|include/" | head -120
curl -s "https://api.github.com/repos/Rakanic/gemmini-rocc-tests/commits/$C" | grep -E '"message"|"date"' | head -3
