# M6.3C negative controls (scratch copies only). C0: forced old-row operand = -0 instead of +0 (reproduces the old first-write -0 behaviour). C1: multiplier rounds toward zero (mode 1) instead of RNE.
S7=/mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3a-s7.sh
F0=src/main/scala/nvfp4pe/NvFp4RmwPipe.scala
F1=src/main/scala/nvfp4pe/Fp32Mul2.scala
W=$HOME/nvfp4-logs/m6.3a-work
# grep counts BEFORE (on the real sources)
R=/mnt/c/Users/braed/gemmini-nvfp4/hw/nvfp4pe
echo "C0 before: $(grep -c 'Mux(accAtAdder, io.rd_data(e)(32 \* j + 31, 32 \* j), 0.U(32.W))' $R/$F0) (want 1 mutation target)"
echo "C1 before: $(grep -c 'rnd.io.roundingMode := 0.U' $R/$F1) (want 1)"
bash $S7 c0neg "sed -i 's/Mux(accAtAdder, io.rd_data(e)(32 \* j + 31, 32 \* j), 0.U(32.W))/Mux(accAtAdder, io.rd_data(e)(32 * j + 31, 32 * j), \"h80000000\".U(32.W))/' $F0; echo \"C0 after: \$(grep -c 'h80000000' $F0)\"" "testOnly nvfp4pe.NvFp4AccSpec"
bash $S7 c1neg "sed -i 's/rnd.io.roundingMode := 0.U/rnd.io.roundingMode := 1.U/' $F1; echo \"C1 after: \$(grep -c 'roundingMode := 1.U' $F1)\"" "testOnly nvfp4pe.Fp32MulSpec"
echo done > $W/c3neg.done
