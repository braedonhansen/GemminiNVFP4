# genus_int8.tcl -- M7.P0 / P0.2: Genus 25.1 synthesis of stock INT8 Gemmini (module Gemmini, GemminiRocketConfig).
# Run (tcsh, after `source ~/setup_ee477_ee577a_v2602.csh`):
#   /tools/cadence/DDI251/GENUS251/bin/genus -no_gui -batch -files genus_int8.tcl -log genus
# Parameters come from the environment (run.csh sets them); defaults below.
#   LIB_PATH    liberty file(s), space separated.   default: OSU FreePDK45 gscl45nm.lib
#   CLK_NS      clock period in ns                  default: 5.0   (see docs/M7.P0-flow.md for why)
#   RTL_DIR     directory holding the SV files      default: ./rtl
#   FILELIST    file list (relative to RTL_DIR)     default: ./filelist.f
#   OUT_DIR     netlist/sdc/db output               default: ./out
#   RPT_DIR     reports                             default: ./reports
#   NCPU        local cpus                          default: 4
# Every command marked "VERIFY" was written from the Genus command reference as remembered (the 25.1 docs are only on
# the school server) and has not been executed; docs/M7.P0-flow.md lists them all. Failures of VERIFY commands are
# caught where that is safe, and the script prints "M7P-*" status lines that run.csh greps.
proc envdef {name def} { if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) } else { return $def } }
set LIB_PATH  [envdef LIB_PATH "/tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files/gscl45nm.lib"]
set CLK_NS    [envdef CLK_NS 5.0]
set RTL_DIR   [envdef RTL_DIR [file normalize ./rtl]]
set FILELIST  [envdef FILELIST [file normalize ./filelist.f]]
set OUT_DIR   [envdef OUT_DIR [file normalize ./out]]
set RPT_DIR   [envdef RPT_DIR [file normalize ./reports]]
set NCPU      [envdef NCPU 4]
set TOP       Gemmini
set MACROS    {mem_ext mem_0_ext}     ;# SRAM black boxes (P0.1: 4x mem_ext + 2x mem_0_ext under Gemmini)
set EXPECT_MACRO_INSTS 6
file mkdir $OUT_DIR $RPT_DIR
puts "M7P-PARAMS lib=$LIB_PATH clk_ns=$CLK_NS rtl=$RTL_DIR top=$TOP"

# ---------------------------------------------------------------- setup
set_db / .init_lib_search_path [list [file dirname [lindex $LIB_PATH 0]]]       ;# VERIFY attribute name (legacy `set_attribute init_lib_search_path`)
set_db / .init_hdl_search_path [list $RTL_DIR]
catch {set_multi_cpu_usage -local_cpu $NCPU}                                      ;# VERIFY
set_db / .hdl_language sv                                                          ;# VERIFY (value sv vs v2001)
catch {set_db / .hdl_verilog_defines {SYNTHESIS}}                                  ;# VERIFY: Gemmini.sv guards sim-only init code with `ifndef SYNTHESIS
set_db / .information_level 6                                                      ;# more messages in the log
# keep Gemmini's hierarchy so area/power can be reported per block (default auto_ungroup would flatten during syn_map)
set_db / .auto_ungroup none                                                        ;# VERIFY (values none|both|area|delay)

set libs {}
foreach l $LIB_PATH { if {![file exists $l]} { puts "M7P-FAIL library file missing: $l"; exit 2 }; lappend libs $l }
read_libs $libs                                                                    ;# VERIFY (25.1: read_libs; older: set_db library)
puts "M7P-LIBS-READ [llength $libs]"

# ---------------------------------------------------------------- RTL
set fl {}
set fh [open $FILELIST r]
while {[gets $fh line] >= 0} { set line [string trim $line]; if {$line ne ""} { lappend fl [file join $RTL_DIR $line] } }
close $fh
if {[llength $fl] < 100} { puts "M7P-FAIL file list has only [llength $fl] entries (expected 135)"; exit 2 }
puts "M7P-FILES [llength $fl]"
read_hdl -sv $fl                                                                   ;# VERIFY (-sv flag; alternatively `read_hdl -language sv`)
# SRAM stubs (sram_stubs.sv) are ports-only modules: elaborate keeps them as empty modules, which are the black boxes.
elaborate $TOP
set_db / .current_design [get_db designs $TOP]                                     ;# VERIFY
check_design -unresolved                                                           ;# VERIFY option name; unresolved references must be 0 (macros resolve to the stubs)

# count the macro instances found (a check that finds nothing must fail)
set nmac 0
foreach m $MACROS {
  set insts [get_db hinsts -if ".module.name == $m"]                               ;# VERIFY: hinst object / .module.name attribute
  puts "M7P-MACRO $m instances=[llength $insts]"
  incr nmac [llength $insts]
}
if {$nmac != $EXPECT_MACRO_INSTS} { puts "M7P-FAIL expected $EXPECT_MACRO_INSTS macro instances, found $nmac"; exit 3 }
# mark the stubs as black boxes / do-not-touch so they are neither optimised away (undriven outputs) nor mapped
foreach m $MACROS {
  catch {set_db [get_db modules $m] .preserve true}                                ;# VERIFY
  catch {set_db [get_db modules $m] .blackbox true}                                ;# VERIFY: attribute may be named .is_black_box / .black_box
  catch {set_db [get_db hinsts -if ".module.name == $m"] .preserve true}           ;# VERIFY
  catch {set_db [get_db hinsts -if ".module.name == $m"] .dont_touch true}         ;# VERIFY
}
puts "M7P-ELABORATED"

# ---------------------------------------------------------------- constraints (written as SDC, then read)
set sdc_in [file join $OUT_DIR Gemmini_in.sdc]
set f [open $sdc_in w]
puts $f "create_clock -name clk -period $CLK_NS \[get_ports clock\]"
puts $f "set_clock_uncertainty [expr {0.05*$CLK_NS}] \[get_clocks clk\]"
puts $f "set_input_delay  [expr {0.2*$CLK_NS}] -clock clk \[remove_from_collection \[all_inputs\] \[get_ports clock\]\]"
puts $f "set_output_delay [expr {0.2*$CLK_NS}] -clock clk \[all_outputs\]"
close $f
read_sdc $sdc_in
# Gemmini has exactly one clock port `clock`; assert the clock sits on a real port
if {[llength [get_db ports -if ".base_name == clock"]] != 1} { puts "M7P-FAIL no port named clock"; exit 3 }   ;# VERIFY
report_clocks > $RPT_DIR/clocks.rpt                                                ;# VERIFY

# ---------------------------------------------------------------- default flow
set t0 [clock seconds]
syn_generic
puts "M7P-SYN-GENERIC [expr {[clock seconds]-$t0}]s"
syn_map
puts "M7P-SYN-MAP [expr {[clock seconds]-$t0}]s"
syn_opt
puts "M7P-SYN-OPT [expr {[clock seconds]-$t0}]s"

# ---------------------------------------------------------------- reports
report_area -depth 3  > $RPT_DIR/area_depth3.rpt                                  ;# VERIFY (-depth)
report_area -depth 2  > $RPT_DIR/area_depth2.rpt
report_gates          > $RPT_DIR/gates.rpt
report_timing -max_paths 10 > $RPT_DIR/timing.rpt                                  ;# VERIFY (-max_paths vs -num_paths)
report_hierarchy      > $RPT_DIR/hierarchy.rpt                                     ;# VERIFY
report_qor            > $RPT_DIR/qor.rpt
check_design          > $RPT_DIR/check_design.rpt
# Vectorless power: a sanity number only (Genus default activity at the primary inputs, propagated). NOT the result.
report_power -depth 3 > $RPT_DIR/power_vectorless.rpt                              ;# VERIFY (-depth; some versions use -levels)
# the macro instances must still be there after mapping
set nmac2 0
foreach m $MACROS { incr nmac2 [llength [get_db hinsts -if ".module.name == $m"]] }
puts "M7P-MACROS-AFTER-MAP $nmac2"
if {$nmac2 != $EXPECT_MACRO_INSTS} { puts "M7P-FAIL macro instances after mapping: $nmac2" }

# ---------------------------------------------------------------- outputs for Joules / later steps
write_hdl > [file join $OUT_DIR Gemmini_netlist.v]                                 ;# VERIFY (`write_hdl` writes the mapped netlist; flag -mapped may be needed)
write_sdc > [file join $OUT_DIR Gemmini.sdc]                                       ;# VERIFY
catch {write_db -common -all_root_attributes -to_file [file join $OUT_DIR Gemmini_genus.db]}  ;# VERIFY: db for Joules `read_db`; the netlist route does not need it
catch {write_design -innovus -basename [file join $OUT_DIR Gemmini_innovus]}       ;# VERIFY, optional (P&R later)
puts "M7P-DONE"
exit 0
