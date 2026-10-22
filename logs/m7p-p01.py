#!/usr/bin/env python3
"""M7.P0.1: collect every module reachable from Gemmini, stub SRAM *_ext macros, list macro instances.
usage: m7p-p01.py <outdir>   (reads the stock GemminiRocketConfig gen-collateral; writes only under outdir)"""
import os, re, sys, glob, shutil, json
GEN = os.path.expanduser("~/chipyard/sims/verilator/generated-src/chipyard.harness.TestHarness.GemminiRocketConfig")
GC = GEN + "/gen-collateral"
out = sys.argv[1]
rtl = out + "/rtl"
shutil.rmtree(out, ignore_errors=True) if os.path.isdir(out) and out.startswith(os.path.expanduser("~/nvfp4-logs/m7p/")) else None
os.makedirs(rtl)
modre = re.compile(r'^\s*module\s+(\w+)', re.M)
files = sorted(f for f in glob.glob(GC + "/*.sv") + glob.glob(GC + "/*.v") if not f.endswith(".mems.v"))
mod_file, mod_text = {}, {}
for f in files:
    t = open(f).read()
    for m in re.finditer(r'^module\s+(\w+)(.*?)^endmodule', t, re.M | re.S):
        if m.group(1) in mod_file and mod_file[m.group(1)] != f:
            print("DUP module", m.group(1), f, mod_file[m.group(1)])
        mod_file[m.group(1)] = f
        mod_text[m.group(1)] = m.group(0)
print("modules defined in collateral:", len(mod_text), "files:", len(files))
inst_re = re.compile(r'^\s+(\w+)\s+(?:#\([^;]*?\)\s*)?(\w+)\s*\(', re.M)
def children(mod):
    res = []
    for m in inst_re.finditer(mod_text[mod]):
        t, n = m.group(1), m.group(2)
        if t in mod_text or t.endswith("_ext"):  # *_ext = SRAM macro (defined only in *.mems.v, excluded from the scan)
            res.append((n, t))
    return res
ext = set()
reach, stack = {}, ["Gemmini"]
while stack:
    m = stack.pop()
    if m in reach: continue
    reach[m] = mod_file.get(m)
    if m in mod_text:
        for n, t in children(m):
            if t not in mod_text: ext.add(t)
            else: stack.append(t)
assert "Gemmini" in mod_text, "Gemmini not found"
print("reachable from Gemmini (incl. undefined externals):", len(reach), " external (macro) modules:", sorted(ext))
# SRAM stubs from the mems.conf (ports from the generated Verilog definition in top.mems.v)
conf = {}
for l in open(GEN + "/chipyard.harness.TestHarness.GemminiRocketConfig.mems.conf"):
    p = l.split()
    if len(p) >= 8 and p[0] == "name":
        conf[p[1]] = dict(depth=int(p[3]), width=int(p[5]), ports=p[7], mask=(int(p[9]) if len(p) > 9 else 0))
memv = open(GC + "/chipyard.harness.TestHarness.GemminiRocketConfig.top.mems.v").read()
stubs = {}
for e in sorted(ext):
    m = re.search(r'^module\s+' + e + r'\b.*?^endmodule', memv, re.M | re.S)
    assert m, "no definition of " + e
    hdr = re.search(r'module\s+' + e + r'\s*\((.*?)\);', m.group(0), re.S).group(1)
    stubs[e] = "// BLACK-BOX STUB of SRAM macro %s (ports only; behaviour model removed for synthesis)\n(* blackbox *)\nmodule %s(\n%s);\nendmodule\n" % (e, e, hdr.strip())
    hdr_ports = re.findall(r'(input|output)\s+(\[[^\]]+\]\s*)?(\w+)', hdr)
    stubs[e] = stubs[e]
with open(rtl + "/sram_stubs.sv", "w") as fo:
    fo.write("".join(stubs[e] + "\n" for e in sorted(stubs)))
# copy reachable defined modules, preserving one file per source (a file may hold only the one module)
copied = set()
for m, f in sorted(reach.items()):
    if f and f not in copied and m in mod_text:
        shutil.copy(f, rtl + "/" + os.path.basename(f)); copied.add(f)
fl = sorted(os.path.basename(f) for f in copied)
with open(out + "/filelist.f", "w") as fo:
    fo.write("sram_stubs.sv\n" + "".join(x + "\n" for x in fl))
# files that define extra modules not reachable? report
extra = {m for f in copied for m in mod_text if mod_file[m] == f} - set(reach)
print("files copied:", len(copied), "extra (unreachable) modules co-located in copied files:", sorted(extra))
# macro instance list: hierarchical walk
rows = []
def walk(mod, path):
    for n, t in children(mod):
        if t in ext: rows.append((path + "." + n, t))
        elif t in mod_text: walk(t, path + "." + n)
walk("Gemmini", "Gemmini")
print("MACRO INSTANCES under Gemmini: %d" % len(rows))
byt = {}
with open(out + "/macro_instances.txt", "w") as fo:
    for p, t in rows:
        c = conf[t]
        s = "%s | %s | %dx%d | %s | mask_gran %d" % (p, t, c["depth"], c["width"], c["ports"], c["mask"])
        print(s); fo.write(s + "\n")
        byt.setdefault(t, 0); byt[t] += 1
for t, n in byt.items():
    c = conf[t]; print("SUMMARY %s: %d instances x %d bits = %.1f KiB" % (t, n, c["depth"] * c["width"], n * c["depth"] * c["width"] / 8192))
json.dump(dict(rows=rows, conf={t: conf[t] for t in byt}), open(out + "/macros.json", "w"))
print("modules in job (incl %d stubs): %d" % (len(ext), len(reach) - len(ext) + len(ext)))
