source ~/miniforge3/etc/profile.d/conda.sh; conda activate eda
cd /mnt/c/Users/braed/gemmini-nvfp4/hw; W=$(mktemp -d)
yosys -p "read_verilog pe_variants/v1_full_lut.v; read_verilog -sv nvfp4pe/generated/NvFp4Mul.sv nvfp4pe/generated/NvFp4PE.sv; proc; memory_map; flatten; opt; miter -equiv -flatten -make_assert pe_v1 NvFp4PE miter; hierarchy -top miter; sat -verify -prove-asserts miter" 2>&1 | grep -E "SUCCESS|FAIL|failed" | head -2
sed "s/4'h3 :/4'h2 :/" nvfp4pe/generated/NvFp4Mul.sv > $W/bad.sv; grep -c "4'h3 :" nvfp4pe/generated/NvFp4Mul.sv
yosys -p "read_verilog pe_variants/v1_full_lut.v; read_verilog -sv $W/bad.sv nvfp4pe/generated/NvFp4PE.sv; proc; memory_map; flatten; opt; miter -equiv -flatten -make_assert mul_v1 NvFp4Mul miter; hierarchy -top miter; sat -verify -prove-asserts miter" 2>&1 | grep -E "SUCCESS|FAIL|failed" | head -2
