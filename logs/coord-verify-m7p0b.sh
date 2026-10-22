# Coordinator re-check of M7.P0b: lib checks, port diff, INT8 wrapper sims (+ mutation control).
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null
L=/mnt/c/Users/braed/gemmini-nvfp4/hw/power/lib; K=$L/freepdk45; W=~/nvfp4-logs/m7p-coord; rm -rf $W; mkdir -p $W
python3 $L/tools/check_macro_libs.py $K/openram/banks | tail -4
G=~/chipyard/sims/verilator/generated-src/chipyard.harness.TestHarness.GemminiRocketConfig
python3 $L/tools/port_diff.py $K/wrappers/int8 int8 $(ls $G/*mems*.v $G/gen-collateral/*mems*.v 2>/dev/null) 2>&1 | tail -4
sim() { # name tb AW W MG bank wrapperfile
  d=$W/$1; mkdir -p $d; cd $d
  verilator --binary -Wno-fatal -Wno-lint -Wno-style --timing --top-module tb +define+DUT=$1 +define+DUTNAME=\"$1\" +define+AW=$3 +define+W=$4 +define+MG=$5 +define+NCYC=4000 \
    $L/tools/tb/$2.sv $7 $K/openram/banks/$6.v -o simv > build.log 2>&1 || { echo "$1 BUILD FAIL"; tail -5 build.log; return; }
  ./obj_dir/simv | grep TB_RESULT
}
sim mem_ext tb_rw 12 128 8 bk_1rw_256x128_ws8 $K/wrappers/int8/mem_ext.v
sim mem_0_ext tb_wr 9 512 8 bk_1w1r_64x512_ws8 $K/wrappers/int8/mem_0_ext.v
# mutation: read-select register captures the wrong address bits
sed 's/rsel_q <= RW0_addr\[11:8\]/rsel_q <= RW0_addr[10:7]/' $K/wrappers/int8/mem_ext.v > $W/mut_mem_ext.v
grep -c "RW0_addr\[10:7\]" $W/mut_mem_ext.v
sim mem_ext tb_rw 12 128 8 bk_1rw_256x128_ws8 $W/mut_mem_ext.v
