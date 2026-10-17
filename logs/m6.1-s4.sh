source ~/miniforge3/etc/profile.d/conda.sh; conda activate eda
H=/mnt/c/Users/braed/gemmini-nvfp4/hw/pe_variants
O=~/nvfp4-logs/m6.1-work/synth
declare -A F=( [v1]=v1_full_lut [v2]=v2_mag_lut [v3]=v3_decode_mul [v4]=v4_shift_mux [v5]=v5_signfold [v6]=v6_shared_decode )
echo "top,aig_ands,aig_nots,gates_cmos2,depth_ltp,depth_and_levels" | tee $O.csv
for n in v1 v2 v3 v4 v5 v6; do for k in mul pe; do
  bash $H/synth_metrics.sh $O ${k}_$n $H/${F[$n]}.v | tee -a $O.csv
done; done
