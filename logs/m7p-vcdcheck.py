#!/usr/bin/env python3
"""m7p-vcdcheck.py <kernel.vcd> <expected-root-scope-path-dotted> <outdir>: header + body sanity of the dumped VCD.
Prints: size, scope chain, signals ($var count), value changes, timestamps (first/last/count), and whether EVERY $var sits under the
expected Gemmini scope. Exit 1 when the file is empty / has 0 vars / 0 changes / any var outside the scope. Writes <outdir>/window.csh."""
import sys, re, os
f, root, out = sys.argv[1], sys.argv[2], sys.argv[3]
size = os.path.getsize(f)
stack, nvars, outside, nscopes = [], 0, 0, 0
clk_id = None
chain_max = []
ts = None
with open(f, "r", errors="replace") as fh:
    for line in fh:
        line = line.lstrip()
        if line.startswith("$scope"):
            stack.append(line.split()[2]); nscopes += 1
        elif line.startswith("$upscope"):
            stack.pop()
        elif line.startswith("$var"):
            nvars += 1
            p = ".".join(stack)
            if clk_id is None and p == root and line.split()[4] == "clock": clk_id = line.split()[3]
            if not (p == root or p.startswith(root + ".")): outside += 1
        elif line.startswith("$enddefinitions"):
            break
    ntimes = nchanges = 0; first = last = None
    rises = []; cur_t = 0
    for line in fh:
        c = line[0]
        if c == "#":
            t = int(line[1:]); ntimes += 1; cur_t = t
            if first is None: first = t
            last = t
        elif c in "01xzXZbBrR":
            nchanges += 1
            if c == "1" and clk_id is not None and len(rises) < 6 and line[1:].rstrip() == clk_id: rises.append(cur_t)
print("vcd: %s" % f)
print("size_bytes=%d (%.1f MiB)" % (size, size / 1048576))
print("scopes=%d vars=%d vars_outside_root=%d" % (nscopes, nvars, outside))
print("root=%s" % root)
print("timestamps=%d first=%s last=%s (VCD time units)" % (ntimes, first, last))
print("value_changes=%d" % nchanges)
periods = sorted(set(b - a for a, b in zip(rises, rises[1:])))
print("gemmini clock rising edges seen=%d periods_ps=%s" % (len(rises), periods))
if len(periods) == 1: open(out + "/clock_period_ps.txt", "w").write(str(periods[0]) + chr(10))
ok = size > 0 and nvars > 0 and nchanges > 0 and ntimes > 0 and outside == 0 and len(periods) == 1
print("VCDCHECK", "PASS" if ok else "FAIL")
if ok:
    with open(out + "/window.csh", "w") as w:
        w.write("setenv WIN_START_PS %d\nsetenv WIN_END_PS %d\n" % (first, last))
        w.write("setenv DUT \"%s\"\n" % root.replace(".", "/").replace("TOP/", "", 1))
sys.exit(0 if ok else 1)
