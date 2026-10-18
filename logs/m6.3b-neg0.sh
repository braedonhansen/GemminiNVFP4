# B0 negative control: disable the RAW stall (ready tied high) in the scratch copy; confirm the mutation applied before running.
F=src/main/scala/nvfp4pe/NvFp4RmwPipe.scala
MUT="echo before:\$(grep -c 'io.ready := true.B' $F); sed -i 's/io.ready := !hazard/io.ready := true.B/' $F; echo after:\$(grep -c 'io.ready := true.B' $F)"
bash /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3a-s7.sh b0neg "$MUT" "testOnly nvfp4pe.NvFp4AccSpec -- -z NvFp4RmwPipe"
echo "--- result"; cat ~/nvfp4-logs/m6.3a-work/s7_b0neg.done; grep -E "RESULT|MISMATCH|FAILED|Tests:" ~/nvfp4-logs/m6.3a-work/s7_b0neg.log | head
