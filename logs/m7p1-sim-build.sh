# usage: m7p1-sim-build.sh <job>
# Out-of-tree waveform-capable Verilator build of the job's config (generalised from logs/m7p-sim-build.sh). Reads (never writes) the tree's
# generated-src; outputs in ~/nvfp4-logs/m7p1/<job>/sim. Same verilator options as `make -n debug CONFIG=<cfg>` in sims/verilator (identical for the
# three trees, checked in M7.P1), except: -Mdir/-o, patched TestDriver.v (window control + Gemmini monitor), scope-restricted tracing (m7p.vlt).
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m7p1-env.sh
m7p1_design $1 || exit 2
m7p1_shell $TREE
set -e
S=$R/hw/power/sim
G=$GEN
[ -f $G/gen-collateral/TestDriver.v ] || { echo "no generated TestDriver.v in $G"; exit 2; }
# the Gemmini instance name in RocketTile (gemmini in the stock tree, v in the MX trees); must be exactly one
INST=$(grep -h -E '^\s+Gemmini\s+\w+\s*\(' $G/gen-collateral/RocketTile.sv | sed -E 's/^\s+Gemmini\s+(\w+)\s*\(.*/\1/')
[ "$(echo "$INST" | wc -w)" = 1 ] || { echo "FAIL: Gemmini instance name not unique: '$INST'"; exit 3; }
echo "Gemmini instance: $INST"
echo "$INST" > $W/gemmini_inst.txt
SIM=$W/sim
rm -rf $SIM; mkdir -p $SIM
python3 $S/patch_testdriver.py $G/gen-collateral/TestDriver.v $SIM/TestDriver.v $INST
cat > $SIM/m7p.vlt <<EOF
\`verilator_config
// Trace only the Gemmini instance (and everything below it). First rule turns everything off; the second turns the Gemmini subtree on.
tracing_off -scope "*"
tracing_on -scope "TestDriver.testHarness.chiptop0.system.tile_prci_domain.element_reset_domain_rockettile.$INST*" -levels 99
EOF
sed "s#^$G/gen-collateral/TestDriver.v#$SIM/TestDriver.v#" $G/sim_files.common.f > $SIM/sim_files.f
[ "$(grep -c "^$SIM/TestDriver.v" $SIM/sim_files.f)" = 1 ] || { echo "TestDriver substitution failed"; exit 1; }
cd $SIM
CY=$TREE
/usr/bin/time -v verilator --main --timing --cc --exe -CFLAGS " -O3 -std=c++17 -I$CY/.conda-env/riscv-tools/include -I$CY/tools/DRAMSim2 -I$G/gen-collateral   -DVERILATOR" \
 -LDFLAGS " -L$CY/.conda-env/riscv-tools/lib -Wl,-rpath,$CY/.conda-env/riscv-tools/lib -L$CY/sims/verilator -L$CY/tools/DRAMSim2 -lriscv -lfesvr -ldramsim " \
 --threads 1 --threads-dpi all -O3 --x-assign fast --x-initial fast --output-split 10000 --output-split-cfuncs 100 --assert -Wno-fatal --timescale 1ns/1ps --max-num-width 1048576 \
 +define+CLOCK_PERIOD=1.0 +define+RESET_DELAY=777.7 +define+PRINTF_COND=TestDriver.printf_cond +define+STOP_COND=!TestDriver.reset +define+MODEL=TestHarness +define+RANDOMIZE_MEM_INIT +define+RANDOMIZE_REG_INIT +define+RANDOMIZE_GARBAGE_ASSIGN +define+RANDOMIZE_INVALID_ASSIGN +define+SIMULATION +define+GPR_RESET +define+GPR_DUPLICATED +define+DBG_TRACE_CORE_PIPELINE_VCS +define+PERF_ENABLE +define+ICACHE_DISABLE +define+DCACHE_DISABLE +define+GBAR_ENABLE +define+GBAR_CLUSTER_ENABLE +define+FPU_FPNEW \
 $CY/generators/radiance/src/main/resources/vsrc/vortex/third_party/fpnew/src/fpnew_pkg.sv $CY/generators/radiance/src/main/resources/vsrc/vortex/third_party/fpnew/src/fpu_div_sqrt_mvp/hdl/defs_div_sqrt_mvp.sv \
 +define+VERILATOR --top-module TestDriver --vpi \
 +incdir+$CY/generators/radiance/src/main/resources/vsrc/vortex/third_party/fpnew/src/common_cells/include +incdir+$CY/generators/radiance/src/main/resources/vsrc/vortex/third_party/fpnew/src/common_cells/include/common_cells \
 +incdir+$G/gen-collateral -f $SIM/sim_files.f +define+DEBUG -o $SIM/simulator-debug --trace m7p.vlt -Mdir $SIM/obj > $SIM/verilate.log 2>&1
echo "verilate done"; tail -3 $SIM/verilate.log
/usr/bin/time -v make -j8 VM_PARALLEL_BUILDS=1 -C $SIM/obj -f VTestDriver.mk > $SIM/cc.log 2>&1
ls -la $SIM/simulator-debug
grep -E "Maximum resident|Elapsed" $SIM/cc.log $SIM/verilate.log | head
