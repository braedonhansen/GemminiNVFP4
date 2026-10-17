source ~/miniforge3/etc/profile.d/conda.sh; conda activate eda
H=/mnt/c/Users/braed/gemmini-nvfp4/hw/pe_variants
W=~/nvfp4-logs/m6.1-work
SV=$W/chisel_sv
O=$W/synth_chisel
echo "top,aig_ands,aig_nots,gates_cmos2,depth_ltp,depth_and_levels" | tee $O.csv
for t in NvFp4Mul NvFp4PE; do
  RV_OPTS=-sv bash $H/synth_metrics.sh $O $t $SV/$t.sv | tee -a $O.csv
done
proof() { # gold_file gold_top gate_file gate_top label
  yosys -q -l $W/proof_$5.log -p "read_verilog $1; read_verilog -sv $3; proc; memory_map; opt_clean; miter -equiv -flatten -make_assert $2 $4 miter; hierarchy -top miter; flatten; memory_map; opt_clean; sat -verify -prove-asserts -show-ports miter" >/dev/null 2>&1
  echo "$5 rc=$? : $(grep -E 'SUCCESS|FAIL' $W/proof_$5.log | head -1)"
}
proof $H/v1_full_lut.v mul_v1 $SV/NvFp4Mul.sv NvFp4Mul CHISEL_mul
proof $H/v1_full_lut.v pe_v1 $SV/NvFp4PE.sv NvFp4PE CHISEL_pe
