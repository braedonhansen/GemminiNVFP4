cd ~/chipyard-mx/generators/gemmini
git diff --stat 266c593f nvfp4 | tail -25
git diff -U0 266c593f nvfp4 -- src chipyard | awk '/^diff --git/ {f=$3} /^@@/ {print f, $3}' | sed 's|a/||; s|src/main/scala/gemmini/||' 
for f in NvFp4PE NvFp4Mesh NvFp4ScaleStage Fp32AccAdd2 NvFp4RmwPipe NvFp4MeshAdapter; do echo "$f.scala: 1-$(wc -l < src/main/scala/gemmini/$f.scala)"; done
