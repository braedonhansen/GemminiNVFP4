# negative control: drop significand bit 7 of sP in stage 1 (scratch copy only); prove mutation applied
F=src/main/scala/nvfp4pe/NvFp4ScaleStage.scala
echo "before: $(grep -c 'mag \* r0P(i)(6, 0)' $F)"
sed -i 's/s1Prod(i) := mag \* r0P(i)$/s1Prod(i) := mag * r0P(i)(6, 0)/' $F
echo "after: $(grep -c 'mag \* r0P(i)(6, 0)' $F)"
