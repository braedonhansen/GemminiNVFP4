# Out-of-tree waveform-capable Verilator build of stock GemminiRocketConfig. Reads (never writes) ~/chipyard generated-src; outputs in ~/nvfp4-logs/m7p/sim.
# Same verilator options as `make -n debug CONFIG=GemminiRocketConfig` in sims/verilator, except: -Mdir/-o, patched TestDriver.v, scope-restricted tracing (m7p.vlt).
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null 2>&1
set -e
R=/mnt/c/Users/braed/gemmini-nvfp4/hw/power/sim
G=$HOME/chipyard/sims/verilator/generated-src/chipyard.harness.TestHarness.GemminiRocketConfig
W=$HOME/nvfp4-logs/m7p/sim
rm -rf $W; mkdir -p $W
python3 $R/patch_testdriver.py $G/gen-collateral/TestDriver.v $W/TestDriver.v
cp $R/m7p.vlt $W/
sed "s#^$G/gen-collateral/TestDriver.v#$W/TestDriver.v#" $G/sim_files.common.f > $W/sim_files.f
[ "$(grep -c "^$W/TestDriver.v" $W/sim_files.f)" = 1 ] || { echo "TestDriver substitution failed"; exit 1; }
cd $W
/usr/bin/time -v verilator --main --timing --cc --exe -CFLAGS " -O3 -std=c++17 -I$HOME/chipyard/.conda-env/riscv-tools/include -I$HOME/chipyard/tools/DRAMSim2 -I$G/gen-collateral   -DVERILATOR" \
 -LDFLAGS " -L$HOME/chipyard/.conda-env/riscv-tools/lib -Wl,-rpath,$HOME/chipyard/.conda-env/riscv-tools/lib -L$HOME/chipyard/sims/verilator -L$HOME/chipyard/tools/DRAMSim2 -lriscv -lfesvr -ldramsim " \
 --threads 1 --threads-dpi all -O3 --x-assign fast --x-initial fast --output-split 10000 --output-split-cfuncs 100 --assert -Wno-fatal --timescale 1ns/1ps --max-num-width 1048576 \
 +define+CLOCK_PERIOD=1.0 +define+RESET_DELAY=777.7 +define+PRINTF_COND=TestDriver.printf_cond +define+STOP_COND=!TestDriver.reset +define+MODEL=TestHarness +define+RANDOMIZE_MEM_INIT +define+RANDOMIZE_REG_INIT +define+RANDOMIZE_GARBAGE_ASSIGN +define+RANDOMIZE_INVALID_ASSIGN +define+SIMULATION +define+GPR_RESET +define+GPR_DUPLICATED +define+DBG_TRACE_CORE_PIPELINE_VCS +define+PERF_ENABLE +define+ICACHE_DISABLE +define+DCACHE_DISABLE +define+GBAR_ENABLE +define+GBAR_CLUSTER_ENABLE +define+FPU_FPNEW \
 $HOME/chipyard/generators/radiance/src/main/resources/vsrc/vortex/third_party/fpnew/src/fpnew_pkg.sv $HOME/chipyard/generators/radiance/src/main/resources/vsrc/vortex/third_party/fpnew/src/fpu_div_sqrt_mvp/hdl/defs_div_sqrt_mvp.sv \
 +define+VERILATOR --top-module TestDriver --vpi \
 +incdir+$HOME/chipyard/generators/radiance/src/main/resources/vsrc/vortex/third_party/fpnew/src/common_cells/include +incdir+$HOME/chipyard/generators/radiance/src/main/resources/vsrc/vortex/third_party/fpnew/src/common_cells/include/common_cells \
 +incdir+$G/gen-collateral -f $W/sim_files.f +define+DEBUG -o $W/simulator-gemmini-debug --trace m7p.vlt -Mdir $W/obj > $W/verilate.log 2>&1
echo "verilate done"; tail -3 $W/verilate.log
/usr/bin/time -v make -j8 VM_PARALLEL_BUILDS=1 -C $W/obj -f VTestDriver.mk > $W/cc.log 2>&1
ls -la $W/simulator-gemmini-debug
