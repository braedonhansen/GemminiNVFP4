source ~/miniforge3/etc/profile.d/conda.sh; conda activate eda
R=/mnt/c/Users/braed/gemmini-nvfp4
W=~/nvfp4-logs/m6.1-work; mkdir -p $W
cd $R/hw/pe_variants && python3 gen.py
GOLD=$R/refmodel/vectors/e2m1_pairs.hex
for v in v1_full_lut v2_mag_lut v3_decode_mul v4_shift_mux v5_signfold v6_shared_decode; do
  n=${v%%_*}
  iverilog -g2005 -o $W/tbm_$n -DMULMOD=mul_$n -DNAME="\"mul_$n\"" -DGOLD="\"$GOLD\"" tb/tb_mul.v $v.v && vvp $W/tbm_$n | tail -3
  iverilog -g2005 -o $W/tbp_$n -DPEMOD=pe_$n -DNAME="\"pe_$n\"" -DGOLD="\"$GOLD\"" tb/tb_pe.v $v.v && vvp $W/tbp_$n | tail -3
done
