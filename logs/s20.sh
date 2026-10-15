cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git show $B:src/main/scala/gemmini/AccumulatorMem.scala | grep -n -i -E "scale|exp|bf16|fp32|mx_|accumulate|aligned|sum" | head -120
