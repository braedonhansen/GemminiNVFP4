source ~/miniforge3/etc/profile.d/conda.sh; conda activate eda
cd /mnt/c/Users/braed/gemmini-nvfp4/hw
W=$(mktemp -d)
yosys -q -p "read_verilog pe_variants/v1_full_lut.v; read_verilog -sv nvfp4pe/generated/NvFp4Mul.sv nvfp4pe/generated/NvFp4PE.sv; proc; memory_map; flatten; opt; miter -equiv -flatten -make_assert pe_v1 NvFp4PE miter; hierarchy -top miter; sat -verify -prove-asserts miter" > $W/p.log 2>&1; echo "chisel PE vs V1 full LUT: rc=$? $(grep -m1 -o -E 'SUCCESS|FAIL[A-Z]*' $W/p.log)"
for t in "v1_full_lut pe_v1" "v4_shift_mux pe_v4" "v6_shared_decode pe_v6"; do set -- $t; bash pe_variants/synth_metrics.sh $W/m $2 pe_variants/$1.v; done
