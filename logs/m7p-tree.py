import re, sys, os
GC = os.path.expanduser("~/nvfp4-logs/m7p/int8/rtl")
mt = {}
for f in os.listdir(GC):
    t = open(GC + "/" + f).read()
    for m in re.finditer(r'^module\s+(\w+)(.*?)^endmodule', t, re.M | re.S): mt[m.group(1)] = m.group(2)
ire = re.compile(r'^\s+(\w+)\s+(?:#\([^;]*?\)\s*)?(\w+)\s*\(', re.M)
def kids(m): return [(n, t) for t, n in [(a, b) for a, b in ire.findall(mt[m])] if t in mt]
def walk(m, ind, d, maxd):
    for n, t in kids(m):
        print("  " * ind + n + " : " + t)
        if d < maxd: walk(t, ind + 1, d + 1, maxd)
walk("Gemmini", 0, 1, int(sys.argv[1]))
