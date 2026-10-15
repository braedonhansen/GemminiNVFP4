C=350547f9843f46f485d4d1dd4c20b2f52f4844bf
R=https://raw.githubusercontent.com/Rakanic/gemmini-rocc-tests/$C
curl -s $R/bareMetalC/matmul_tiled_fp4_64x64.c | head -150
echo ======
curl -s "https://api.github.com/repos/Rakanic/gemmini-rocc-tests/git/trees/$C?recursive=1" | grep '"path"' | grep -v "bareMetalC/matmul_tiled_asym\|dramloop\|_chunk" | grep -i -E "mx|golden|gen|scripts|\.py|README|include|build" | head -60
