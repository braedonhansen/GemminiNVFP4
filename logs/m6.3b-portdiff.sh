SRC=/mnt/c/Users/braed/gemmini-nvfp4/hw/nvfp4pe/src/main/scala/nvfp4pe
DST=$HOME/chipyard-mx/generators/gemmini/src/main/scala/gemmini
for f in NvFp4PE NvFp4Mesh NvFp4ScaleStage Fp32AccAdd2 NvFp4RmwPipe; do
  if diff <(sed 's/^package gemmini/package nvfp4pe/' $DST/$f.scala) <(awk '/^object Elaborate/ {exit} {print}' $SRC/$f.scala) >/dev/null; then echo "$f: IDENTICAL (package line and Elaborate* objects aside)"; else echo "$f: DIFFERS"; fi
done
# hardfloat: Gemmini tree uses the MX tree's own hardfloat (generators/hardfloat @ 0ecaef09); standalone copy is of the same commit
for f in AddRecFN common fNFromRecFN primitives rawFloatFromFN rawFloatFromRecFN recFNFromFN RoundAnyRawFNToRecFN; do
  cmp -s $HOME/chipyard-mx/generators/hardfloat/hardfloat/src/main/scala/$f.scala $SRC/../hardfloat/$f.scala && echo "hardfloat/$f.scala identical" || echo "hardfloat/$f.scala DIFFERS or missing"
done
