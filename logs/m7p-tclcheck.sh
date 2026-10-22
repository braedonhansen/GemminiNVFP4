# Runs the Genus/Joules scripts against a mock tool shell (syntax/logic check only)
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null 2>&1
M=/mnt/c/Users/braed/gemmini-nvfp4; W=$HOME/nvfp4-logs/m7p/mock; rm -rf $W; mkdir -p $W/act $W/out; cd $W
touch fakelib.lib out/Gemmini_netlist.v out/Gemmini.sdc; echo x > act/kernel.vcd
export LIB_PATH=$W/fakelib.lib RTL_DIR=$HOME/nvfp4-logs/m7p/int8/rtl FILELIST=$HOME/nvfp4-logs/m7p/int8/filelist.f OUT_DIR=$W/out RPT_DIR=$W/reports VCD=$W/act/kernel.vcd
echo "== genus"; tclsh $M/logs/m7p-tclmock.tcl $M/hw/power/genus_int8.tcl genus 2>&1 | tail -15; echo "-- sdc"; cat $W/out/Gemmini_in.sdc
echo "== joules"; tclsh $M/logs/m7p-tclmock.tcl $M/hw/power/joules_int8.tcl joules 2>&1 | tail -12
echo "== negative: macro count wrong (mock returns 4+2; expect 7)"; sed 's/EXPECT_MACRO_INSTS 6/EXPECT_MACRO_INSTS 7/' $M/hw/power/genus_int8.tcl > $W/g7.tcl; tclsh $M/logs/m7p-tclmock.tcl $W/g7.tcl genus 2>&1 | tail -3
echo "== negative: empty vcd"; : > act/kernel.vcd; tclsh $M/logs/m7p-tclmock.tcl $M/hw/power/joules_int8.tcl joules 2>&1 | tail -3
