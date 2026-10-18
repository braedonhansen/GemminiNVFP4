source ~/miniforge3/etc/profile.d/conda.sh; conda activate eda
H=/mnt/c/Users/braed/gemmini-nvfp4/hw/pe_variants
W=$HOME/nvfp4-logs/m6.2-work/mx
echo "top,aig_ands,aig_nots,gates_cmos2,depth_ltp,depth_and_levels" > $W/synth.csv
for v in a85 a45; do
  RV_OPTS=-sv timeout 3000 bash $H/synth_metrics.sh $W/synth_$v MxSystolicArray $W/sv16_$v/MxSystolicArray.sv | sed "s/^MxSystolicArray/MxSystolicArray_$v/" | tee -a $W/synth.csv
  grep -E 'DFF' $W/synth_$v/MxSystolicArray_aig.stat
done
echo DONE >> $W/synth.csv
