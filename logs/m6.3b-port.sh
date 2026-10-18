# Port verified hw/nvfp4pe sources into the Gemmini nvfp4 branch (package gemmini), dropping the standalone Elaborate* objects.
set -e
SRC=/mnt/c/Users/braed/gemmini-nvfp4/hw/nvfp4pe/src/main/scala/nvfp4pe
DST=$HOME/chipyard-mx/generators/gemmini/src/main/scala/gemmini
for f in NvFp4PE NvFp4Mesh NvFp4ScaleStage Fp32AccAdd2 NvFp4RmwPipe; do
  awk '/^object Elaborate/ {exit} {print}' $SRC/$f.scala | sed -e 's/^package nvfp4pe/package gemmini/' > $DST/$f.scala
  echo "$f: $(wc -l < $DST/$f.scala) lines"
done
# NvFp4RmwPipe.scala contains the test wrapper NvFp4AccBank; keep (small), harmless.
