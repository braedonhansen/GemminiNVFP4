# joules_int8.tcl -- M7.P0 / P0.4: Joules 25.1 gate-level power of the Genus-synthesised stock INT8 Gemmini, driven by the
# RTL Verilator VCD of the kernel window (see docs/M7.P0-flow.md).
# Run (tcsh, after the setup file):  /tools/cadence/DDI251/JSTUDIO251/bin/joules -batch -files joules_int8.tcl
# Environment (run.csh sets these):
#   LIB_PATH    liberty file(s)                    default: OSU FreePDK45 gscl45nm.lib
#   OUT_DIR     Genus outputs (netlist/sdc/db)     default: ./out
#   RPT_DIR     reports                            default: ./reports
#   VCD         waveform                           default: ./act/kernel.vcd
#   DUT         scope of Gemmini inside the VCD    default: the path below (Verilator names it TOP.TestDriver....gemmini)
#   WIN_START_PS / WIN_END_PS   kernel window as VCD time, ps (Verilator --timescale 1ns/1ps: 1 cycle = 1000 ps).
#                               default: empty = whole VCD (the VCD only contains the window anyway)
#   JOULES_INPUT   db | netlist                     default: db if out/Gemmini_genus.db exists, else netlist
# "VERIFY" = command/option from memory of the Joules command reference, not yet run (docs/M7.P0-flow.md lists them).
proc envdef {name def} { if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) } else { return $def } }
set LIB_PATH [envdef LIB_PATH "/tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files/gscl45nm.lib"]
set OUT_DIR  [envdef OUT_DIR [file normalize ./out]]
set RPT_DIR  [envdef RPT_DIR [file normalize ./reports]]
set VCD      [envdef VCD [file normalize ./act/kernel.vcd]]
# Scope mapping: in the VCD the Gemmini instance is TOP.TestDriver.testHarness.chiptop0.system.tile_prci_domain.element_reset_domain_rockettile.gemmini
# (Verilator prefixes the root scope with TOP; the Joules path usually omits it). It maps onto the synthesised top module `Gemmini`.
set DUT      [envdef DUT "TestDriver/testHarness/chiptop0/system/tile_prci_domain/element_reset_domain_rockettile/gemmini"]
set T0       [envdef WIN_START_PS ""]
set T1       [envdef WIN_END_PS ""]
set TOP      Gemmini
file mkdir $RPT_DIR
puts "M7P-PARAMS vcd=$VCD dut=$DUT window=$T0..$T1"
if {![file exists $VCD] || [file size $VCD] == 0} { puts "M7P-FAIL VCD missing or empty: $VCD"; exit 2 }
foreach l $LIB_PATH { if {![file exists $l]} { puts "M7P-FAIL library missing: $l"; exit 2 } }

set_db / .init_lib_search_path [list [file dirname [lindex $LIB_PATH 0]]]          ;# VERIFY
read_libs $LIB_PATH                                                                ;# VERIFY

# ---- design: the mapped netlist from Genus. Preferred: Genus db (keeps register names so RTL-VCD names can be matched).
set mode [envdef JOULES_INPUT ""]
if {$mode eq ""} { if {[file exists $OUT_DIR/Gemmini_genus.db]} { set mode db } else { set mode netlist } }
puts "M7P-INPUT $mode"
if {$mode eq "db"} {
  read_db $OUT_DIR/Gemmini_genus.db                                                ;# VERIFY (Joules read_db of a Genus write_db database)
} else {
  read_netlist $OUT_DIR/Gemmini_netlist.v                                          ;# VERIFY
  if {[catch {elaborate $TOP} err]} { puts "M7P-NOTE elaborate after read_netlist: $err" }  ;# may be unnecessary in the netlist flow
  read_sdc $OUT_DIR/Gemmini.sdc
}

# ---- activity: RTL VCD -> gate netlist, kernel window only.
# The VCD root scope is TOP (Verilator), so Gemmini sits at TOP/TestDriver/.../gemmini. Try the likely spellings of the
# DUT scope in turn and keep the first one that annotates signals; print which one worked.
foreach c {rtlstim2gate_init rtlstim2gate} { if {![catch {$c} e]} { puts "M7P-RTLSTIM2GATE via $c"; break } else { puts "M7P-NOTE $c: $e" } }
set slash [string map {. /} $DUT]
set cands [list "TOP/$slash" "/TOP/$slash" $slash "TOP.[string map {/ .} $slash]"]
set ok 0
foreach cand $cands {
  set stim_opts [list -file $VCD -format vcd -dut_instance $cand]                   ;# VERIFY option names (-dut_instance, -format)
  if {$T0 ne "" && $T1 ne ""} { lappend stim_opts -start $T0 -end $T1 }             ;# VERIFY units (ps, the VCD timescale)
  if {[catch {eval read_stimulus $stim_opts} err]} { puts "M7P-TRY dut=$cand failed: $err"; continue }
  puts "M7P-TRY dut=$cand ok"; set ok 1; break
}
if {!$ok} { puts "M7P-FAIL read_stimulus: no DUT scope spelling matched"; exit 3 }
puts "M7P-STIMULUS-READ"

# ---- power
compute_power -mode time_based                                                      ;# VERIFY (-mode time_based vs vectorbased|average)
report_power -unit mW -out $RPT_DIR/power_total.rpt                              ;# VERIFY
report_power -by_hierarchy -levels 4 -unit mW -out $RPT_DIR/power_by_hier_l4.rpt ;# VERIFY
report_power -by_hierarchy -levels 2 -unit mW -out $RPT_DIR/power_by_hier_l2.rpt
# Group breakdown. Instance paths under Gemmini (from the RTL tree, P0.1):
#   mesh           : ex_controller/mesh/mesh                       (the 16x16 systolic array)
#   spad_banks     : spad/spad_mems_0..3 (wrapper logic only; the SRAM macros are black boxes, no power here -> P2)
#   acc            : spad/acc_mems_0..1 (AccumulatorMem logic; macros excluded as above) and spad/acc_scale_unit
#   dma            : spad/reader, spad/writer, spad/xbar, spad/buffer*, tlb
#   controllers    : load_controller, store_controller, ex_controller (minus mesh/mesh), reservation_station, mod (LoopConv), mod_1 (LoopMatmul), raw_cmd_q, unrolled_cmd_q
#   other          : everything else (counters, im2col, arbiters, spad queues ...)
set groups {
  mesh        {ex_controller/mesh/mesh}
  spad_banks  {spad/spad_mems_0 spad/spad_mems_1 spad/spad_mems_2 spad/spad_mems_3}
  acc         {spad/acc_mems_0 spad/acc_mems_1 spad/acc_scale_unit}
  dma         {spad/reader spad/writer spad/xbar spad/buffer spad/buffer_1 spad/buffer_2 tlb}
  controllers {load_controller store_controller ex_controller reservation_station mod mod_1 raw_cmd_q unrolled_cmd_q}
}
foreach {g insts} $groups {
  foreach i $insts {
    set safe [string map {/ _} $i]
    # one report per instance; the groups above are summed from these once the report format is known (first server run),
    # remembering to subtract ex_controller/mesh/mesh from ex_controller
    set f $RPT_DIR/power_inst_${g}__${safe}.rpt
    if {[catch {report_power -inst $i -levels 1 -unit mW -out $f} e1] && [catch {report_power -inst $TOP/$i -levels 1 -unit mW -out $f} e2]} {
      puts "M7P-WARN per-instance report failed for $i: $e1 / $e2"
    }
  }
}

# ---- annotation coverage: read the 'Annotation Report' table that read_stimulus prints into joules.out
puts "M7P-DONE"
exit 0
