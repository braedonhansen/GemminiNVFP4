source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.1-env.sh
W=$HOME/nvfp4-logs/m6.2-work; mkdir -p $W/sv
rm -rf $W/projE; mkdir -p $W/projE; cp -r /mnt/c/Users/braed/gemmini-nvfp4/hw/nvfp4pe/{build.sbt,project,src} $W/projE/
cd $W/projE
sbt -batch "runMain nvfp4pe.ElaborateMesh $W/sv 16 0" "runMain nvfp4pe.ElaborateMesh $W/sv 4 0" "runMain nvfp4pe.ElaborateMesh $W/sv 16 1" > $W/elab.log 2>&1; echo "sbt rc=$?"
ls -la $W/sv
source ~/miniforge3/etc/profile.d/conda.sh; conda activate eda
H=/mnt/c/Users/braed/gemmini-nvfp4/hw/pe_variants
O=$W/synth
echo "top,aig_ands,aig_nots,gates_cmos2,depth_ltp,depth_and_levels" | tee $W/synth.csv
for t in NvFp4Mesh_d4_l0 NvFp4Mesh_d16_l0 NvFp4Mesh_d16_l1; do
  RV_OPTS=-sv bash $H/synth_metrics.sh $O $t $W/sv/$t.sv | tee -a $W/synth.csv
  grep -E 'DFF|dff' $O/${t}_aig.stat | head -3
done
