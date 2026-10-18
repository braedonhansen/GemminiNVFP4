# Elaborate a standalone MX FP4 16x16 systolic array (MxGen MxSystolicArray) from a COPY of the mxgen sources. MX tree untouched.
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.1-env.sh
W=$HOME/nvfp4-logs/m6.2-work/mx; rm -rf $W; mkdir -p $W/src/main/scala $W/project
cp -r $HOME/chipyard-mx/generators/gemmini/mxgen/src/main/scala/. $W/src/main/scala/
cp /mnt/c/Users/braed/gemmini-nvfp4/hw/nvfp4pe/project/* $W/project/ 2>/dev/null
cp /mnt/c/Users/braed/gemmini-nvfp4/hw/nvfp4pe/build.sbt $W/build.sbt
cat > $W/src/main/scala/ElabMxSa.scala <<'EOS'
package mxgen
object ElabMxSa extends App {
  val n = args(1).toInt
  val acc = args(2).toInt  // acc exp
  val accSig = args(3).toInt
  val cfg = MxConfig.fp4Only.copy(productFormat = MxFormat.Custom(4, 4), accFormat = MxFormat.Custom(acc, accSig))
  val opts = Array("-disable-all-randomization", "-strip-debug-info", "--lowering-options=disallowLocalVariables,noAlwaysComb")
  circt.stage.ChiselStage.emitSystemVerilogFile(new MxSystolicArray(Seq.fill(n)(cfg), lut = false, latency = 0), Array("--target-dir", args(0)), opts)
}
EOS
cd $W
sbt -batch "runMain mxgen.ElabMxSa $W/sv16_a85 16 8 8" "runMain mxgen.ElabMxSa $W/sv16_a45 16 4 5" > $W/elab.log 2>&1; echo "sbt rc=$?"
tail -5 $W/elab.log; ls -la $W/sv16_a85 $W/sv16_a45
