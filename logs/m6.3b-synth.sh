# B0 synthesis: per-stage depth of the 2-stage adder (same Yosys flow as m6.3a-synth.sh), plus the 1-cycle adder for reference.
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.1-env.sh
W=$HOME/nvfp4-logs/m6.3b-work; mkdir -p $W/sv
rm -rf $W/projE; mkdir -p $W/projE; cp -r /mnt/c/Users/braed/gemmini-nvfp4/hw/nvfp4pe/{build.sbt,project,src} $W/projE/
cd $W/projE
sbt -batch "runMain nvfp4pe.ElaborateB0 $W/sv" "runMain nvfp4pe.ElaborateScale $W/sv" > $W/elab.log 2>&1; echo "sbt rc=$?"
ls $W/sv
source ~/miniforge3/etc/profile.d/conda.sh; conda activate eda
H=/mnt/c/Users/braed/gemmini-nvfp4/hw/pe_variants
O=$W/synth
echo "top,aig_ands,aig_nots,gates_cmos2,depth_ltp,depth_and_levels" | tee $W/synth.csv
for t in Fp32AddS1 Fp32AddS2 Fp32AccAdd2 Fp32AccAdd NvFp4AccBank; do
  RV_OPTS=-sv bash $H/synth_metrics.sh $O $t $W/sv/$t.sv | tee -a $W/synth.csv
  grep -E 'DFF|dff' $O/${t}_aig.stat | head -3
done
