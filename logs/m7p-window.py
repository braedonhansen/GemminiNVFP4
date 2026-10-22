#!/usr/bin/env python3
"""m7p-window.py <pass1.log> <outdir>: kernel window from the Gemmini monitor lines (M7P ...) of a no-dump run.
start = first RoCC command fire after the 'M7P kernel start' marker; end = last io_busy falling edge (after the last mvout/fence).
Fails when it finds no fires / no busy edge / inconsistent counts. Writes <outdir>/window.txt (key=value)."""
import re, sys, os
log, out = sys.argv[1], sys.argv[2]
lines = open(log, errors="replace").read().splitlines()
ks = [i for i, l in enumerate(lines) if l.startswith("M7P kernel start")]
ke = [i for i, l in enumerate(lines) if l.startswith("M7P kernel end")]
if len(ks) != 1 or len(ke) != 1: sys.exit("FAIL: kernel start/end markers: %d/%d (want 1/1)" % (len(ks), len(ke)))
fire = re.compile(r"M7P FIRE cycle=(\d+) t_ns=([\d.]+) n=(\d+) funct=(\d+)")
busy = re.compile(r"M7P BUSY([01]) cycle=(\d+) t_ns=([\d.]+) nfire=(\d+)")
fires = [(i, int(m.group(1)), float(m.group(2)), int(m.group(3)), int(m.group(4))) for i, l in enumerate(lines) for m in [fire.match(l)] if m]
edges = [(i, int(m.group(1)), int(m.group(2)), float(m.group(3)), int(m.group(4))) for i, l in enumerate(lines) for m in [busy.match(l)] if m]
if not fires or not edges: sys.exit("FAIL: no M7P FIRE/BUSY lines (monitor produced nothing)")
kf = [f for f in fires if f[0] > ks[0]]
if not kf: sys.exit("FAIL: no command fire after the kernel-start marker")
start_cycle, start_ns, start_n = kf[0][1], kf[0][2], kf[0][3]
rises_after = [e for e in edges if e[1] == 1 and e[2] >= start_cycle]
falls = [e for e in edges if e[1] == 0 and e[2] >= start_cycle]
if not falls: sys.exit("FAIL: no busy falling edge after the first kernel command")
end = falls[-1]
total_n = max(e[4] for e in edges)
if end[4] != total_n: sys.exit("FAIL: last busy fall has nfire=%d but total fires=%d (commands after the end?)" % (end[4], total_n))
# the kernel marker order check: start must come after the previous (flush) busy fall
pre = [e for e in edges if e[2] < start_cycle]
if pre and pre[-1][1] != 0: sys.exit("FAIL: Gemmini busy while the kernel was supposed to start")
cmds_in_window = end[4] - (start_n - 1)
os.makedirs(out, exist_ok=True)
with open(out + "/window.txt", "w") as f:
    f.write("start_cycle=%d\nend_cycle=%d\nstart_t_ns=%.3f\nend_t_ns=%.3f\nlength_cycles=%d\nkernel_commands_fired=%d\nfires_total=%d\nbusy_edges_in_window=%d\n" %
            (start_cycle, end[2], start_ns, end[3], end[2] - start_cycle + 1, cmds_in_window, total_n, len([e for e in edges if e[2] >= start_cycle])))
print(open(out + "/window.txt").read())
