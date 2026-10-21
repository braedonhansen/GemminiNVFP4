source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $LG; V=$R/refmodel/vectors
make nvfp4_unit 2>&1 | tail -3
echo "== D3 pass run"; ./nvfp4_unit $V/scale_stage.txt.gz $V/acc_seq.txt.gz; echo rc=$?
echo "== D3 negative control: first write stores blk directly (no +0 + blk)"
N=~/nvfp4-logs/d3neg; rm -rf $N; mkdir -p $N; cp nvfp4_math.h nvfp4_unit.cc $N/
echo "before: $(grep -c 'return f32_add(first ? 0u : prev, blk);' $N/nvfp4_math.h)"
sed -i 's/return f32_add(first ? 0u : prev, blk);/return first ? blk : f32_add(prev, blk);/' $N/nvfp4_math.h
echo "after (mutation applied): $(grep -c 'return first ? blk : f32_add(prev, blk);' $N/nvfp4_math.h)"
g++ -ffp-contract=off -std=c++17 -O2 -o $N/nvfp4_unit_neg $N/nvfp4_unit.cc && $N/nvfp4_unit_neg $V/scale_stage.txt.gz $V/acc_seq.txt.gz; echo rc=$?
