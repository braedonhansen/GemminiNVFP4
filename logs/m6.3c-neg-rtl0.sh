# System-level control for the -0 fix: temporarily force the adder's old-row operand to -0 on a non-accumulating write (the pre-fix behaviour) in the branch,
# rebuild the NVFP4 simulator, run nvfp4_e2e (expect mismatches on exactly the outputs that depend on -0 + ... ), then restore the committed file and rebuild.
R=/mnt/c/Users/braed/gemmini-nvfp4; G=~/chipyard-mx/generators/gemmini; F=src/main/scala/gemmini/NvFp4RmwPipe.scala
cd $G
echo "before: $(grep -c '0.U(32.W))' $F) / h80000000: $(grep -c 'h80000000' $F)"
sed -i 's/Mux(accAtAdder, io.rd_data(e)(32 \* j + 31, 32 \* j), 0.U(32.W))/Mux(accAtAdder, io.rd_data(e)(32 * j + 31, 32 * j), "h80000000".U(32.W))/' $F
echo "after: h80000000 = $(grep -c 'h80000000' $F)  (mutation applied if 1)"
git status --short | grep -v rocc-tests
bash $R/logs/m6.3b-build.sh NvFp4GemminiRocketConfig rtl0neg | head -1
bash $R/logs/m6.3c-run.sh rtl0neg | grep -v "^if \|^	"
echo "--- restore committed file and rebuild"
git checkout -- $F
echo "restored: h80000000 = $(grep -c 'h80000000' $F); git status:"; git status --short | grep -v rocc-tests; echo "(clean)"
bash $R/logs/m6.3b-build.sh NvFp4GemminiRocketConfig rtl0restore | head -1
bash $R/logs/m6.3c-run.sh r3 | grep -v "^if \|^	"
echo rtl0-finished > ~/nvfp4-logs/m6.3c-rtl0.done
