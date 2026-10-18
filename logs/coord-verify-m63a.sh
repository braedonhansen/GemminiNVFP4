# Coordinator check for M6.3A: full suite on a clean copy, then a sign-path mutation (must fail).
W=$HOME/nvfp4-logs/m6.3a-work
L=/mnt/c/Users/braed/gemmini-nvfp4/logs
bash $L/m6.3a-s7.sh coordfull
echo "full: $(cat $W/s7_coordfull.done) | $(grep -E 'Tests:' $W/s7_coordfull.log)"
MUT='F=src/main/scala/nvfp4pe/NvFp4ScaleStage.scala; sed -i "s/s0S(i) := io.sa(i)(7) ^ io.sb(i)(7)/s0S(i) := io.sa(i)(7)/" $F; echo MUTATED=$(grep -c "s0S(i) := io.sa(i)(7)$" $F)'
bash $L/m6.3a-s7.sh coordneg "$MUT" "testOnly nvfp4pe.NvFp4ScaleSpec"
echo "neg: $(cat $W/s7_coordneg.done) | $(grep -E 'Tests:' $W/s7_coordneg.log)"
grep -m3 -i -E "mismatch" $W/s7_coordneg.log | cut -c1-120
