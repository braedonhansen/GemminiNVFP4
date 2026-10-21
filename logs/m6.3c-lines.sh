cd ~/chipyard-mx/generators/gemmini/src/main/scala/gemmini
grep -n "accAtAdder\|wr_data(e) :=" NvFp4RmwPipe.scala
grep -n "use_nvfp4\|NvMulStage\|Fp32MulS1\|Fp32MulS2\|factor\|Pipeline(in" AccumulatorScale.scala | head -30
grep -n "out_fp32\|fp32x" LoopMatmul.scala
grep -n "out_fp32" Controller.scala
grep -n "config.use_nvfp4" Scratchpad.scala
wc -l Fp32Mul2.scala
git diff 266c593f --stat -- . | tail -3
git diff ee5991cd --stat -- . | tail -8
