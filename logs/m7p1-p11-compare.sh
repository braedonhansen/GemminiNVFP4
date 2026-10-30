#!/bin/bash
# M7.P1.1: call-trace comparison of the M7.P0 scripts (hw/power/p0, the ones that ran on the server) with the generalised scripts on job a's parameters.
# Run logs/m7p1-tclcheck.sh int8-stock-a old|new first. Only the mock directory name may differ.
M=$HOME/nvfp4-logs/m7p1/mock
norm() { sed 's/int8-stock-a\.\(old\|new\)\.normal/MOCKDIR/g' "$1"; }
O=$(wc -l < $M/int8-stock-a.old.normal/trace.txt); N=$(wc -l < $M/int8-stock-a.new.normal/trace.txt)
[ "$O" -gt 50 ] || { echo "P11-FAIL old trace has $O calls (checked nothing)"; exit 1; }
if diff <(norm $M/int8-stock-a.old.normal/trace.txt) <(norm $M/int8-stock-a.new.normal/trace.txt) > /tmp/p11.diff; then echo "P11-TRACE-IDENTICAL calls old=$O new=$N (after normalising the mock directory name)"; else echo "P11-TRACE-DIFFERS"; cat /tmp/p11.diff | head -20; exit 1; fi
echo "marker lines that differ (old vs new):"
diff <(cat $M/int8-stock-a.old.normal/genus.out $M/int8-stock-a.old.normal/joules.out | grep "^M7P-" | sed 's/ [0-9]*s$//' | norm /dev/stdin) <(cat $M/int8-stock-a.new.normal/genus.out $M/int8-stock-a.new.normal/joules.out | grep "^M7P-" | sed 's/ [0-9]*s$//' | norm /dev/stdin) | cut -c1-200
