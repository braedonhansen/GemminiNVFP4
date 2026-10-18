# Single MX FP4 PE (MxFpMul, fp4Only) from the scratch copy; the array synth is too slow, this gives the per-PE number.
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.1-env.sh
W=$HOME/nvfp4-logs/m6.2-work/mxpe; rm -rf $W; mkdir -p $W/src/main/scala $W/project
cp -r $HOME/chipyard-mx/generators/gemmini/mxgen/src/main/scala/. $W/src/main/scala/
cp /mnt/c/Users/braed/gemmini-nvfp4/hw/nvfp4pe/project/* $W/project/ 2>/dev/null
cp /mnt/c/Users/braed/gemmini-nvfp4/hw/nvfp4pe/build.sbt $W/build.sbt
cat > $W/src/main/scala/ElabMxPe.scala <<'EOS'
package mxgen
object ElabMxPe extends App {
  val cfg = MxConfig.fp4Only.copy(productFormat = MxFormat.Custom(4, 4), accFormat = MxFormat.Custom(args(1).toInt, args(2).toInt))
  val opts = Array("-disable-all-randomization", "-strip-debug-info", "--lowering-options=disallowLocalVariables,noAlwaysComb")
  circt.stage.ChiselStage.emitSystemVerilogFile(new MxFpMul(cfg, lut = false, latency = 0), Array("--target-dir", args(0)), opts)
}
EOS
cd $W
sbt -batch "runMain mxgen.ElabMxPe $W/sv_a85 8 8" "runMain mxgen.ElabMxPe $W/sv_a45 4 5" > $W/elab.log 2>&1; echo "sbt rc=$?"
source ~/miniforge3/etc/profile.d/conda.sh; conda activate eda
H=/mnt/c/Users/braed/gemmini-nvfp4/hw/pe_variants
echo "top,aig_ands,aig_nots,gates_cmos2,depth_ltp,depth_and_levels" > $W/synth.csv
for v in a85 a45; do
  RV_OPTS=-sv bash $H/synth_metrics.sh $W/synth_$v MxFpMul $W/sv_$v/MxFpMul.sv | sed "s/^MxFpMul/MxFpMul_$v/" | tee -a $W/synth.csv
done
echo DONE >> $W/synth.csv
