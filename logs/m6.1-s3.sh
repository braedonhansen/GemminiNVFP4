source ~/miniforge3/etc/profile.d/conda.sh; conda activate eda
R=/mnt/c/Users/braed/gemmini-nvfp4
H=$R/hw/pe_variants
W=~/nvfp4-logs/m6.1-work; mkdir -p $W/neg
cd $H
declare -A F=( [v1]=v1_full_lut [v2]=v2_mag_lut [v3]=v3_decode_mul [v4]=v4_shift_mux [v5]=v5_signfold [v6]=v6_shared_decode )
# equiv.ys template
proof() { # file_gold file_gate kind top_gold top_gate label
  yosys -q -l $W/proof_$6.log -p "read_verilog $1; read_verilog $2; proc; memory_map; opt_clean; miter -equiv -flatten -make_assert $4 $5 miter; hierarchy -top miter; flatten; memory_map; opt_clean; sat -verify -prove-asserts -show-ports miter" >/dev/null 2>&1
  rc=$?
  echo "$6 rc=$rc : $(grep -E 'SUCCESS|FAIL|QED|Proof' $W/proof_$6.log | head -2 | tr '\n' ' ')"
}
for n in v2 v3 v4 v5 v6; do
  proof $H/v1_full_lut.v $H/${F[$n]}.v mul mul_v1 mul_$n mul_$n
  proof $H/v1_full_lut.v $H/${F[$n]}.v pe pe_v1 pe_$n pe_$n
done
# sanity: V1 vs itself via renamed copy is trivial; skip.
# negative control: break V4 (9 -> 8 for m3a&m3b)
sed "s/default: base = 4'd9;/default: base = 4'd8;/" $H/v4_shift_mux.v > $W/neg/v4_broken.v
diff $H/v4_shift_mux.v $W/neg/v4_broken.v
proof $H/v1_full_lut.v $W/neg/v4_broken.v mul mul_v1 mul_v4 NEG_mul_v4
proof $H/v1_full_lut.v $W/neg/v4_broken.v pe pe_v1 pe_v4 NEG_pe_v4
grep -iE 'counter|FAIL|Time' $W/proof_NEG_mul_v4.log | head -5
# also confirm the simulation testbench catches it
GOLD=$R/refmodel/vectors/e2m1_pairs.hex
iverilog -g2005 -o $W/neg/tbm -DMULMOD=mul_v4 -DNAME="\"mul_v4_broken\"" -DGOLD="\"$GOLD\"" tb/tb_mul.v $W/neg/v4_broken.v && vvp $W/neg/tbm | grep RESULT
iverilog -g2005 -o $W/neg/tbp -DPEMOD=pe_v4 -DNAME="\"pe_v4_broken\"" -DGOLD="\"$GOLD\"" tb/tb_pe.v $W/neg/v4_broken.v && vvp $W/neg/tbp | grep RESULT
