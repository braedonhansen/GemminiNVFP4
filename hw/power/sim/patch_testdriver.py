#!/usr/bin/env python3
"""patch_testdriver.py <in TestDriver.v> <out TestDriver.v>: add the M7.P0 window control + Gemmini monitor.
Fails (exit 1) unless every anchor was found exactly once, so a changed upstream file cannot silently skip the patch."""
import sys, re, os
src = open(sys.argv[1]).read()
mon = open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "m7p_monitor.vh")).read()
GEM = "testHarness.chiptop0.system.tile_prci_domain.element_reset_domain_rockettile.gemmini"
def sub1(pat, rep, s):
    n = s.count(pat)
    if n != 1: sys.exit("anchor count %d != 1 for: %r" % (n, pat))
    return s.replace(pat, rep)
src = sub1("module TestDriver;\n", "module TestDriver;\n\n`define M7P_GEM " + GEM + "\n  reg m7p_has_win = 1'b0;\n", src)
src = sub1('    verbose = $test$plusargs("verbose");\n', '    verbose = $test$plusargs("verbose");\n    m7p_has_win = $test$plusargs("m7p-start=");\n', src)
# Verilator 5.022 ignores $dumpon/$dumpoff (tested), so the window is made by calling $dumpvars at the window start
# (from the monitor) and $finish at its end; in window mode the time-0 $dumpvars is skipped.
src = sub1("      $dumpvars(0, testHarness);\n", "      if (!m7p_has_win) $dumpvars(0, testHarness);\n", src)
src = sub1("    if (dump_start == 0)\n", "    if (dump_start == 0 && !m7p_has_win)\n", src)
src = sub1("  `MODEL testHarness(", mon + "\n  `MODEL testHarness(", src)
open(sys.argv[2], "w").write(src)
print("patched", sys.argv[2])
