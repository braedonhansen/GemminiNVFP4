source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null
L=/mnt/c/Users/braed/gemmini-nvfp4/hw/power/lib; K=$L/freepdk45; W=~/nvfp4-logs/m7p-coord
G=~/chipyard/sims/verilator/generated-src/chipyard.harness.TestHarness.GemminiRocketConfig
python3 $L/tools/port_diff.py $K/wrappers int8 $(ls $G/*mems*.v $G/gen-collateral/*mems*.v 2>/dev/null) 2>&1 | tail -4
simacc() { d=$W/acc_$1; rm -rf $d; mkdir -p $d; cd $d
  verilator --binary -Wno-fatal -Wno-lint -Wno-style --timing --top-module tb +define+DUT=mem_0_ext +define+DUTNAME=\"mem_0_ext\" +define+HAS_MASK +define+AW=9 +define+W=512 +define+MG=8 +define+NCYC=4000 \
    $L/tools/tb/tb_wr.sv $2 $K/openram/banks/bk_1w1r_64x512_ws8.v -o simv > build.log 2>&1 || { echo BUILD FAIL; tail -5 build.log; return; }
  echo -n "$1: "; ./obj_dir/simv | grep TB_RESULT; }
simacc good $K/wrappers/int8/mem_0_ext.v
grep -n "rsel_q <=" $K/wrappers/int8/mem_0_ext.v | head -2
sed -E 's/(rsel_q <= R0_addr)\[8:6\]/\1[7:5]/' $K/wrappers/int8/mem_0_ext.v > $W/mut_mem_0_ext.v; grep -c "R0_addr\[7:5\]" $W/mut_mem_0_ext.v
simacc mutated $W/mut_mem_0_ext.v
