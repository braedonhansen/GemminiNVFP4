# M6.3C port check: every ported component is identical to the verified standalone source (package line and Elaborate* objects aside)
SRC=/mnt/c/Users/braed/gemmini-nvfp4/hw/nvfp4pe/src/main/scala/nvfp4pe
DST=$HOME/chipyard-mx/generators/gemmini/src/main/scala/gemmini
for f in NvFp4PE NvFp4Mesh NvFp4ScaleStage Fp32AccAdd2 NvFp4RmwPipe Fp32Mul2; do
  if diff <(sed 's/^package gemmini/package nvfp4pe/' $DST/$f.scala) <(awk '/^object Elaborate/ {exit} {print}' $SRC/$f.scala) >/dev/null; then echo "$f: IDENTICAL (package line and Elaborate* objects aside)"; else echo "$f: DIFFERS"; fi
done
for f in AddRecFN common fNFromRecFN primitives rawFloatFromFN rawFloatFromRecFN recFNFromFN RoundAnyRawFNToRecFN MulRecFN; do
  cmp -s $HOME/chipyard-mx/generators/hardfloat/hardfloat/src/main/scala/$f.scala $SRC/../hardfloat/$f.scala && echo "hardfloat/$f.scala identical" || echo "hardfloat/$f.scala DIFFERS or missing"
done
