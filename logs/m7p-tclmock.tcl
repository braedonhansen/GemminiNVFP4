# Mock Genus/Joules shell: defines every tool command used by hw/power/*.tcl as a logging no-op and sources the script,
# to catch Tcl syntax/logic errors locally (it cannot validate the tool's own command syntax). usage: tclsh m7p-tclmock.tcl <script.tcl> <genus|joules>
set script [lindex $argv 0]; set kind [lindex $argv 1]
set ::calls {}
foreach c {set_multi_cpu_usage read_libs read_hdl elaborate check_design read_sdc report_clocks syn_generic syn_map syn_opt report_area report_gates report_timing
           report_hierarchy report_qor write_hdl write_sdc write_db write_design report_power read_db read_netlist read_stimulus compute_power report_annotation
           report_activity_annotation report_activity} {
  proc $c args "lappend ::calls \[list $c \$args\]; return {}"
}
proc set_db args { lappend ::calls [list set_db $args]; return {} }
proc get_db {kind args} {
  lappend ::calls [list get_db $kind $args]
  if {$kind eq "hinsts"} {
    if {[string match "*mem_0_ext*" $args]} { return {a b} } elseif {[string match "*mem_ext*" $args]} { return {a b c d} }
  }
  if {$kind eq "ports"} { return {p} }
  if {$kind eq "insts"} { return {f1 f2 f3} }
  return {}
}
rename exit real_exit
proc exit {{code 0}} { puts "MOCK-EXIT $code ([llength $::calls] tool calls)"; set ::env(MOCK_RESULT) $code; real_exit $code }
if {[catch {source $script} err]} { puts "MOCK-TCL-ERROR: $err\n$::errorInfo"; real_exit 9 }
