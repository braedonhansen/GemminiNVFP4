# genus_gemmini.tcl -- M7.P1: Genus 25.1 synthesis of one Gemmini design (module Gemmini), generalised from the M7.P0 INT8 script
# (hw/power/p0/genus_int8.tcl, which ran on the server for job int8-stock-a). Every int8-stock-a fix is kept:
#   - .current_design is read-only in Genus 25.1 (TUI-26): elaborate makes $TOP current, we only check it
#   - report_power has no -depth
#   - the markers run.csh greps start at the beginning of a line (M7P-...)
# Run (tcsh, after the course setup file):  genus -no_gui -batch -files genus_gemmini.tcl -log reports/genus
# Parameters come from the environment (run.csh sets them from window.csh); the defaults reproduce job int8-stock-a.
#   LIB_PATH      liberty files, space separated.  default: OSU FreePDK45 gscl45nm.lib (job a); jobs b.. pass Nangate45 + the design's OpenRAM *_pj.lib banks
#   CLK_NS        clock period in ns               default: 5.0
#   RTL_DIR       directory holding the SV files   default: ./rtl
#   FILELIST      file list (relative to RTL_DIR)  default: ./filelist.f
#   WRAPPER_DIR   directory with the design's SRAM wrapper .v files (ONE wrappers/<design> folder).  default: empty = the RTL file list
#                 carries ports-only black-box stubs for the SRAM macros (job a)
#   MACRO_MODS    module names of the SRAM macros  default: "mem_ext mem_0_ext"
#   EXPECT_MACRO_INSTS  instances of those modules under $TOP  default: 6
#   BANK_MODS / EXPECT_BANKS   (wrapper mode) liberty bank cells and the expected number of bank-cell instances in total,
#                 e.g. BANK_MODS="bk_1rw_256x128_ws8 bk_1w1r_64x512_ws8"  EXPECT_BANKS="bk_1rw_256x128_ws8=64 bk_1w1r_64x512_ws8=16".  If unset the bank check is skipped.
#   MIN_FILES     minimum number of RTL files in FILELIST  default: 100
#   TOP           top module                       default: Gemmini
#   OUT_DIR / RPT_DIR / NCPU   as before (./out, ./reports, 4)
# Commands that were never run before the first server run carry the old "VERIFY" marks; the ones int8-stock-a proved are unmarked.
proc envdef {name def} { if {[info exists ::env($name)] && $::env($name) ne ""} { return $::env($name) } else { return $def } }
set LIB_PATH  [envdef LIB_PATH "/tools/PDK/NCSU45PDK/FreePDK45/osu_soc/lib/files/gscl45nm.lib"]
set CLK_NS    [envdef CLK_NS 5.0]
set RTL_DIR   [envdef RTL_DIR [file normalize ./rtl]]
set FILELIST  [envdef FILELIST [file normalize ./filelist.f]]
set WRAPPER_DIR [envdef WRAPPER_DIR ""]
set OUT_DIR   [envdef OUT_DIR [file normalize ./out]]
set RPT_DIR   [envdef RPT_DIR [file normalize ./reports]]
set NCPU      [envdef NCPU 4]
set TOP       [envdef TOP Gemmini]
set MACROS    [envdef MACRO_MODS "mem_ext mem_0_ext"]   ;# SRAM macro modules (stub black boxes in job a, wrapper modules in jobs b..)
set EXPECT_MACRO_INSTS [envdef EXPECT_MACRO_INSTS 6]
set BANK_MODS [envdef BANK_MODS ""]
set EXPECT_BANKS [envdef EXPECT_BANKS ""]
set MIN_FILES [envdef MIN_FILES 100]
file mkdir $OUT_DIR $RPT_DIR
puts "M7P-PARAMS lib=$LIB_PATH clk_ns=$CLK_NS rtl=$RTL_DIR top=$TOP wrappers=$WRAPPER_DIR macros=$MACROS x$EXPECT_MACRO_INSTS banks=$EXPECT_BANKS"

# ---------------------------------------------------------------- bank-cell counting (wrapper mode)
# Two independent ways, both must be tried; the count has to equal EXPECT_BANKS or the job stops (a check that finds nothing fails).
#  1. get_db insts -if ".base_cell.name == <bank>"            (Genus object model; attribute names VERIFY)
#  2. parse a written Verilog netlist: bank-cell instance lines per module x number of instances of that module (hinsts)
proc m7p_bank_counts_db {banks} {
  set res {}
  foreach b $banks {
    if {[catch {set n [llength [get_db insts -if ".base_cell.name == $b"]]} err]} { return {} }
    lappend res $b $n
  }
  return $res
}
proc m7p_bank_counts_netlist {file wrappers banks} {
  # per wrapper module: its bank-cell instances in the netlist text, times the number of hinsts of that module
  if {![file exists $file] || [file size $file] == 0} { return {} }
  set cur ""; array set per {}
  set fh [open $file r]
  while {[gets $fh line] >= 0} {
    if {[regexp {^\s*module\s+(\S+?)\s*\(} $line -> m]} { set cur $m; continue }
    if {[regexp {^\s*endmodule} $line]} { set cur ""; continue }
    if {$cur ne "" && [regexp {^\s*(\S+)\s+\\?\S+\s*\(} $line -> cell] && [lsearch -exact $banks $cell] >= 0} {
      if {![info exists per($cur,$cell)]} { set per($cur,$cell) 0 }
      incr per($cur,$cell)
    }
  }
  close $fh
  array set tot {}
  foreach b $banks { set tot($b) 0 }
  foreach w $wrappers {
    set nh [llength [get_db hinsts -if ".module.name == $w"]]
    foreach key [array names per] {
      lassign [split $key ,] m cell
      if {$m eq $w} { incr tot($cell) [expr {$per($key) * $nh}] }
    }
  }
  set res {}
  foreach b $banks { lappend res $b $tot($b) }
  return $res
}
proc m7p_bank_check {tag file wrappers banks expect} {
  # expect: list of bank=count. Returns 1 if satisfied.
  array set want {}
  foreach e $expect { lassign [split $e =] b n; set want($b) $n }
  set got [m7p_bank_counts_db $banks]
  set via db
  set ok 1
  foreach b $banks { if {![dict exists $got $b] || [dict get $got $b] != $want($b)} { set ok 0 } }
  if {!$ok} {
    set got [m7p_bank_counts_netlist $file $wrappers $banks]
    set via netlist
    set ok 1
    if {[llength $got] == 0} { set ok 0 }
    foreach b $banks { if {![dict exists $got $b] || [dict get $got $b] != $want($b)} { set ok 0 } }
  }
  set total 0
  foreach b $banks { if {[dict exists $got $b]} { incr total [dict get $got $b] } }
  puts "M7P-BANKS-$tag via=$via counts=$got total=$total expected=$expect"
  return $ok
}

# ---------------------------------------------------------------- setup
set lib_dirs {}
foreach l $LIB_PATH { set d [file dirname $l]; if {[lsearch -exact $lib_dirs $d] < 0} { lappend lib_dirs $d } }
set_db / .init_lib_search_path $lib_dirs                                           ;# VERIFY attribute name (legacy `set_attribute init_lib_search_path`); job a: one directory
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
if {[llength $fl] < $MIN_FILES} { puts "M7P-FAIL file list has only [llength $fl] entries (expected at least $MIN_FILES)"; exit 2 }
puts "M7P-FILES [llength $fl]"
# SRAM wrappers: ONE design folder (wrappers/<design>). Their modules carry the Chisel macro names (mem_ext ...) and instantiate the
# OpenRAM bank cells, which are liberty cells (read_libs above) and therefore hard macros, never inferred or optimised.
set wl {}
if {$WRAPPER_DIR ne ""} {
  set wl [lsort [glob -nocomplain -directory $WRAPPER_DIR *.v]]
  if {[llength $wl] == 0} { puts "M7P-FAIL no wrapper files in $WRAPPER_DIR"; exit 2 }
  set wn {}
  foreach w $wl { lappend wn [file tail $w] }
  puts "M7P-WRAPPERS [llength $wl] from [file tail $WRAPPER_DIR]: $wn"
}
read_hdl -sv [concat $wl $fl]                                                      ;# VERIFY (-sv flag; alternatively `read_hdl -language sv`)
# job a: SRAM stubs (sram_stubs.sv) are ports-only modules: elaborate keeps them as empty modules, which are the black boxes.
elaborate $TOP
# Genus 25.1: .current_design is read-only (TUI-26); elaborate already makes $TOP current, so check it instead of setting it
set cur [get_db designs $TOP]
if {[llength $cur] != 1} { puts "M7P-FAIL design $TOP not found after elaborate"; exit 2 }
puts "M7P-DESIGN [get_db $cur .name]"
check_design -unresolved                                                           ;# VERIFY option name; unresolved references must be 0 (macros resolve to the stubs / wrappers)

# count the macro instances found (a check that finds nothing must fail)
set nmac 0
foreach m $MACROS {
  set insts [get_db hinsts -if ".module.name == $m"]                               ;# VERIFY: hinst object / .module.name attribute
  puts "M7P-MACRO $m instances=[llength $insts]"
  incr nmac [llength $insts]
}
if {$nmac != $EXPECT_MACRO_INSTS} { puts "M7P-FAIL expected $EXPECT_MACRO_INSTS macro instances, found $nmac"; exit 3 }
if {$BANK_MODS ne ""} {
  # wrapper mode: the bank cells inside the wrappers must be there as library cells, in the expected number
  set elab_v [file join $OUT_DIR ${TOP}_elab.v]
  if {[catch {write_hdl > $elab_v} err]} { puts "M7P-NOTE write_hdl after elaborate: $err" }
  if {![m7p_bank_check ELAB $elab_v $MACROS $BANK_MODS $EXPECT_BANKS]} { puts "M7P-FAIL bank-cell count after elaboration differs from $EXPECT_BANKS"; exit 3 }
  file delete -force $elab_v
  puts "M7P-MARK skipped (wrapper mode: the wrappers are logic, the banks are library cells)"
} else {
  # mark the stubs as black boxes / do-not-touch so they are neither optimised away (undriven outputs) nor mapped
  foreach m $MACROS {
    catch {set_db [get_db modules $m] .preserve true}                              ;# VERIFY
    catch {set_db [get_db modules $m] .blackbox true}                              ;# VERIFY: attribute may be named .is_black_box / .black_box
    catch {set_db [get_db hinsts -if ".module.name == $m"] .preserve true}         ;# VERIFY
    catch {set_db [get_db hinsts -if ".module.name == $m"] .dont_touch true}       ;# VERIFY
  }
}
puts "M7P-ELABORATED"

# ---------------------------------------------------------------- constraints (written as SDC, then read)
set sdc_in [file join $OUT_DIR ${TOP}_in.sdc]
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
catch {report_power > $RPT_DIR/power_vectorless.rpt}                              ;# Genus 25.1 report_power has no -depth
# the macro instances must still be there after mapping
set nmac2 0
foreach m $MACROS { incr nmac2 [llength [get_db hinsts -if ".module.name == $m"]] }
puts "M7P-MACROS-AFTER-MAP $nmac2"
if {$nmac2 != $EXPECT_MACRO_INSTS} {
  # wrapper mode: the wrappers are ordinary logic, which syn_map uniquifies/renames, so a module-name count no longer
  # finds them all (int8-stock-b: 2 of 6). The bank-cell count on the mapped netlist below is the check there.
  if {$BANK_MODS ne ""} { puts "M7P-NOTE wrapper instances found by module name after mapping: $nmac2 (bank check decides)" } else { puts "M7P-FAIL macro instances after mapping: $nmac2" }
}

# ---------------------------------------------------------------- outputs for Joules / later steps
write_hdl > [file join $OUT_DIR ${TOP}_netlist.v]                                  ;# VERIFY (`write_hdl` writes the mapped netlist; flag -mapped may be needed)
write_sdc > [file join $OUT_DIR ${TOP}.sdc]                                        ;# VERIFY
if {$BANK_MODS ne ""} {
  # the same bank check on the mapped netlist (the file Joules reads)
  if {![m7p_bank_check MAPPED [file join $OUT_DIR ${TOP}_netlist.v] $MACROS $BANK_MODS $EXPECT_BANKS]} { puts "M7P-FAIL bank-cell count in the mapped netlist differs from $EXPECT_BANKS" }
}
catch {write_db -common -all_root_attributes -to_file [file join $OUT_DIR ${TOP}_genus.db]}  ;# VERIFY: db (Joules cannot read this format, see int8-stock-a; kept for later Innovus use)
catch {write_design -innovus -basename [file join $OUT_DIR ${TOP}_innovus]}       ;# VERIFY, optional (P&R later)
puts "M7P-DONE"
exit 0
