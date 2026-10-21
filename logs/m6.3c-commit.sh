cd ~/chipyard-mx/generators/gemmini
G="git -c user.name=Braedonhansen -c user.email=braedon.hansen@gmail.com"
git reset -q
git add src/main/scala/gemmini/NvFp4RmwPipe.scala
$G commit -q -F - <<'MSG'
NVFP4: first accumulator write goes through the adder as +0 + blk (M6.3C -0 fix)

The first write of a pass used to store the scaled block directly, so a -0 block (zero scale, negative lane sum) was stored as -0
while the refmodel computes +0 + blk = +0. The old-row operand of the adder is now forced to +0 when the write does not accumulate.
(Ported unchanged from hw/nvfp4pe NvFp4RmwPipe.)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git add src/main/scala/gemmini/Fp32Mul2.scala src/main/scala/gemmini/AccumulatorScale.scala src/main/scala/gemmini/Scratchpad.scala src/main/scala/gemmini/LoopMatmul.scala src/main/scala/gemmini/Controller.scala
$G commit -q -F - <<'MSG'
NVFP4 FP32 mvout with the tensor scale via acc_scale (M6.3C)

- AccumulatorScale (use_nvfp4): every DMA read of the accumulator multiplies its 4 x FP32 lanes by the FP32 acc_scale carried by the
  read request (RNE, 2 elastic stages Fp32MulS1/Fp32MulS2 = hardfloat MulRawFN + RoundRawFNToRecFN, ported from hw/nvfp4pe Fp32Mul2),
  before the BF16-mode passthrough of MxRequantizer
- LoopMatmulStCSpad (out_fp32): the spad store's address math doubles for 4-byte elements (chunk 8 rows, j-group 8, row tile, row step)
- MX configs unchanged (generated MX Verilog identical modulo source-line annotations)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git log --oneline -4
git status --short | grep -v rocc-tests; echo status-done
