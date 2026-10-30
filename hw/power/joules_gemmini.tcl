# joules_gemmini.tcl -- M7.P1: Joules 25.1 gate-level power of a Genus-synthesised Gemmini design, driven by the RTL Verilator VCD of the
# kernel window. Generalised from hw/power/p0/joules_int8.tcl (ran on the server for job int8-stock-a). Every int8-stock-a fix is kept:
#   - the design is read from the Genus NETLIST (read_netlist + read_sdc); Joules cannot read the `write_db -common` database
#   - the VCD scope needs the TOP/ prefix (Verilator's root); the spellings are tried in turn
#   - report_power takes -out, not -outfile
#   - rtlstim2gate is enabled before read_stimulus (Joules' STIM-0551 advice)
# Run (tcsh, after the setup file):  joules -batch -files joules_gemmini.tcl -log reports/joules
# Environment (run.csh sets these from window.csh):
#   LIB_PATH    liberty files (space separated)    default: OSU FreePDK45 gscl45nm.lib (job a)
#   TOP         top module                          default: Gemmini
#   OUT_DIR / RPT_DIR / VCD   as before (./out, ./reports, ./act/kernel.vcd)
#   DUT         scope of Gemmini inside the VCD     default: the stock path (same for every design in M7: Verilator names it TOP.TestDriver....gemmini)
#   WIN_START_PS / WIN_END_PS   kernel window as VCD time, ps (after the rescale to the synthesis clock)
#   JOULES_INPUT   netlist | db                     default: netlist (job a's fix)
#   GROUPS_TCL  optional file defining `groups` (per-design instance list); default: the stock INT8 list below (job a)
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
set TOP      [envdef TOP Gemmini]
file mkdir $RPT_DIR
puts "M7P-PARAMS vcd=$VCD dut=$DUT window=$T0..$T1"
if {![file exists $VCD] || [file size $VCD] == 0} { puts "M7P-FAIL VCD missing or empty: $VCD"; exit 2 }
foreach l $LIB_PATH { if {![file exists $l]} { puts "M7P-FAIL library missing: $l"; exit 2 } }

set lib_dirs {}
foreach l $LIB_PATH { set d [file dirname $l]; if {[lsearch -exact $lib_dirs $d] < 0} { lappend lib_dirs $d } }
set_db / .init_lib_search_path $lib_dirs                                           ;# VERIFY
read_libs $LIB_PATH                                                                ;# VERIFY

# ---- design: the mapped netlist from Genus (job a's fix: the netlist, not the Genus db).
set mode [envdef JOULES_INPUT netlist]
puts "M7P-INPUT $mode"
if {$mode eq "db"} {
  read_db $OUT_DIR/${TOP}_genus.db                                                 ;# kept for completeness; fails on the `write_db -common` format
} else {
  read_netlist $OUT_DIR/${TOP}_netlist.v                                           ;# VERIFY
  if {[catch {elaborate $TOP} err]} { puts "M7P-NOTE elaborate after read_netlist: $err" }  ;# may be unnecessary in the netlist flow
  read_sdc $OUT_DIR/${TOP}.sdc
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
# Group breakdown. Default = stock INT8 instance paths under Gemmini (from the RTL tree, M7.P0.1). Other designs ship GROUPS_TCL
# (written at pack time from the design's own hierarchy), which defines `groups` the same way.
#   mesh           : ex_controller/mesh/mesh                       (the systolic array)
#   spad_banks     : spad/spad_mems_0..3 (wrapper logic and, in jobs b.., the bank cells under it)
#   acc            : spad/acc_mems_0..1 and spad/acc_scale_unit
#   dma            : spad/reader, spad/writer, spad/xbar, spad/buffer*, tlb
#   controllers    : load_controller, store_controller, ex_controller (minus mesh/mesh), reservation_station, mod (LoopConv), mod_1 (LoopMatmul), raw_cmd_q, unrolled_cmd_q
set groups {
  mesh        {ex_controller/mesh/mesh}
  spad_banks  {spad/spad_mems_0 spad/spad_mems_1 spad/spad_mems_2 spad/spad_mems_3}
  acc         {spad/acc_mems_0 spad/acc_mems_1 spad/acc_scale_unit}
  dma         {spad/reader spad/writer spad/xbar spad/buffer spad/buffer_1 spad/buffer_2 tlb}
  controllers {load_controller store_controller ex_controller reservation_station mod mod_1 raw_cmd_q unrolled_cmd_q}
}
set gt [envdef GROUPS_TCL ""]
if {$gt ne ""} {
  if {![file exists $gt]} { puts "M7P-FAIL GROUPS_TCL missing: $gt"; exit 2 }
  source $gt
  puts "M7P-GROUPS from [file tail $gt]: [llength $groups]"
}
set ninst 0; set nfail 0
foreach {g insts} $groups {
  foreach i $insts {
    incr ninst
    set safe [string map {/ _} $i]
    # one report per instance; the groups above are summed from these once the report format is known (first server run),
    # remembering to subtract ex_controller/mesh/mesh from ex_controller
    set f $RPT_DIR/power_inst_${g}__${safe}.rpt
    if {[catch {report_power -inst $i -levels 1 -unit mW -out $f} e1] && [catch {report_power -inst $TOP/$i -levels 1 -unit mW -out $f} e2]} {
      incr nfail
      puts "M7P-WARN per-instance report failed for $i: $e1 / $e2"
    }
  }
}
puts "M7P-INST-REPORTS requested=$ninst failed=$nfail"

# ---- annotation coverage: read the 'Annotation Report' table that read_stimulus prints into joules.out
puts "M7P-DONE"
exit 0
