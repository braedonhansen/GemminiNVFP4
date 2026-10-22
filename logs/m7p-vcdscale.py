#!/usr/bin/env python3
"""m7p-vcdscale.py <in.vcd> <out.vcd> <num> <den>: multiply every VCD timestamp by num/den (must stay integral).
Used so the simulated Gemmini clock period (2000 ps, tile clock = half the TestDriver clock) equals the SDC clock period of the
synthesis job (e.g. 5000 ps), i.e. the toggle rates Joules sees correspond to the synthesised clock. Only '#<time>' lines change.
Prints the number of timestamps rewritten; exits 1 if none or a non-integral result."""
import sys
src, dst, num, den = sys.argv[1], sys.argv[2], int(sys.argv[3]), int(sys.argv[4])
n = 0
with open(src, "r", errors="replace") as fi, open(dst, "w") as fo:
    hdr = True
    for line in fi:
        if line[0] == "#":
            t = int(line[1:]) * num
            if t % den: sys.exit("non-integral timestamp after scaling: %s" % line.strip())
            fo.write("#%d\n" % (t // den)); n += 1
        else:
            fo.write(line)
print("rewrote %d timestamps by %d/%d" % (n, num, den))
sys.exit(0 if n > 0 else 1)
