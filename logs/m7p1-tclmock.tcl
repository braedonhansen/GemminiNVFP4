# Mock Genus/Joules shell (M7.P1): defines every tool command used by hw/power/*.tcl as a logging no-op and sources the script, to check the Tcl
# control flow and the parameters locally (it cannot validate the tool's own command syntax). Extends logs/m7p-tclmock.tcl:
#   - every call is appended to the trace file $::env(MOCK_TRACE) (paths made job-relative), so two script versions can be diffed
#   - get_db answers from MOCK_MACRO_COUNTS ("mem_ext=4 mem_0_ext=2") and MOCK_BANK_COUNTS ("bk_a=64 ...")
#   - write_hdl > file writes the wrapper modules found in $::env(MOCK_WRAPPERS) (a directory) so the netlist-parsing bank count has something to read
#   - read_libs / read_hdl / read_netlist / read_sdc / read_stimulus fail when a file does not exist
# usage: tclsh m7p1-tclmock.tcl <script.tcl> <genus|joules>
set script [lindex $argv 0]; set kind [lindex $argv 1]
set ::calls {}
set ::job [expr {[info exists ::env(MOCK_JOBDIR)] ? $::env(MOCK_JOBDIR) : ""}]
proc norm {s} { if {$::job ne ""} { set s [string map [list $::job JOBDIR] $s] }; return $s }
proc logcall {c args} {
  lappend ::calls $c
  if {[info exists ::env(MOCK_TRACE)]} { set f [open $::env(MOCK_TRACE) a]; puts $f "[norm [concat $c $args]]"; close $f }
}
foreach c {set_multi_cpu_usage check_design read_sdc report_clocks syn_generic syn_map syn_opt report_area report_gates report_timing
           report_hierarchy report_qor write_sdc write_db write_design report_power read_db compute_power report_annotation
           report_activity_annotation report_activity rtlstim2gate_init rtlstim2gate} {
  proc $c args "logcall $c {*}\$args; return {}"
}
proc elaborate args { logcall elaborate {*}$args; return {} }
proc read_libs {libs} { logcall read_libs {*}$libs; foreach l $libs { if {![file exists $l]} { error "mock: library $l missing" } }; return {} }
proc read_hdl args { logcall read_hdl {*}$args; foreach f [lindex $args end] { if {![file exists $f]} { error "mock: hdl $f missing" } }; return {} }
proc read_netlist args { logcall read_netlist {*}$args; if {![file exists [lindex $args 0]]} { error "mock: netlist missing" }; return {} }
proc read_stimulus args { logcall read_stimulus {*}$args; return {} }
proc write_hdl args {
  logcall write_hdl {*}$args
  if {[lindex $args 0] eq ">" && [info exists ::env(MOCK_WRAPPERS)]} {
    set f [open [lindex $args 1] w]
    foreach w [lsort [glob -nocomplain -directory $::env(MOCK_WRAPPERS) *.v]] { set h [open $w r]; puts $f [read $h]; close $h }
    close $f
  } elseif {[lindex $args 0] eq ">"} { set f [open [lindex $args 1] w]; puts $f "// mock netlist"; close $f }
  return {}
}
proc set_db args { logcall set_db {*}$args; return {} }
proc counts {var} { array set a {}; if {[info exists ::env($var)]} { foreach kv $::env($var) { lassign [split $kv =] k v; set a($k) $v } }; return [array get a] }
proc get_db {kind args} {
  logcall get_db $kind {*}$args
  set flat [join $args " "]
  if {$kind eq "hinsts"} {
    array set a [counts MOCK_MACRO_COUNTS]
    foreach m [array names a] { if {[string match "*== $m*" $flat]} { return [lrepeat $a($m) h] } }
    return {}
  }
  if {$kind eq "insts"} {
    array set b [counts MOCK_BANK_COUNTS]
    if {[info exists ::env(MOCK_NO_DB_BANKS)]} { error "mock: attribute not available" }
    foreach m [array names b] { if {[string match "*== $m*" $flat]} { return [lrepeat $b($m) i] } }
    return {}
  }
  if {$kind eq "ports"} { return {p} }
  if {$kind eq "designs"} { return {d} }
  if {[string match ".name" [lindex $args 0]]} { return Gemmini }
  return {}
}
rename exit real_exit
proc exit {{code 0}} { logcall exit $code; puts "MOCK-EXIT $code ([llength $::calls] tool calls)"; real_exit $code }
if {[catch {source $script} err]} { puts "MOCK-TCL-ERROR: $err\n$::errorInfo"; real_exit 9 }
