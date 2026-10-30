#!/usr/bin/env python3
"""M7.P1 RTL extraction (generalised from logs/m7p-p01.py).

usage: m7p1-extract.py <gen-dir> <config> <wrapper-design> <outdir>
  gen-dir          .../sims/verilator/generated-src/chipyard.harness.TestHarness.<config>
  wrapper-design   folder name under hw/power/lib/freepdk45/wrappers (int8, fp32, mxfp4, mxfp8, nvfp4)
  outdir           job working directory (rtl/, filelist.f, macro_instances.txt, wrappers/, groups.tcl, extract.json are written there)

Collects every module reachable from `Gemmini` (copied unmodified from gen-collateral), finds the SRAM macro modules (`*_ext`, defined only in
*.top.mems.v, so excluded from the scan), and pairs them with the wrapper folder of that design: every macro module the design uses must have a
wrapper of the same name with identical ports (port_diff), and every wrapper file must be used. The macro instances under Gemmini are listed with
the OpenRAM bank cells inside each wrapper. Fails (exit 1) when nothing was found, a macro has no wrapper, a wrapper is unused or a port differs.
"""
import glob, json, os, re, shutil, sys

gen, cfg, wdesign, out = sys.argv[1:5]
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
WDIR = os.path.join(REPO, "hw/power/lib/freepdk45/wrappers", wdesign)
sys.path.insert(0, os.path.join(REPO, "hw/power/lib/tools"))
import port_diff as pd

GC = gen + "/gen-collateral"
assert os.path.isdir(GC), "no gen-collateral in " + gen
assert os.path.isdir(WDIR), "no wrapper folder " + WDIR
if os.path.isdir(out):
    assert out.startswith(os.path.expanduser("~/nvfp4-logs/m7p1/")), "refusing to clear " + out
    shutil.rmtree(out)
rtl, wout = out + "/rtl", out + "/wrappers"
os.makedirs(rtl); os.makedirs(wout)

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
        if t in mod_text or t.endswith("_ext"):
            res.append((n, t))
    return res


ext = set()
reach, stack = {}, ["Gemmini"]
assert "Gemmini" in mod_text, "Gemmini module not found"
while stack:
    m = stack.pop()
    if m in reach:
        continue
    reach[m] = mod_file.get(m)
    if m in mod_text:
        for n, t in children(m):
            if t not in mod_text:
                ext.add(t)
            else:
                stack.append(t)
print("reachable from Gemmini:", len([m for m in reach if m in mod_text]), " SRAM macro modules:", sorted(ext))
if not ext:
    sys.exit("FAIL: no SRAM macro modules found under Gemmini (checked nothing)")

# wrappers: exactly this design's folder; names must equal the macro modules used
wfiles = sorted(os.path.basename(f)[:-2] for f in glob.glob(WDIR + "/*.v"))
if sorted(ext) != wfiles:
    sys.exit("FAIL: macro modules %s != wrapper files %s" % (sorted(ext), wfiles))
for n in wfiles:
    shutil.copy(os.path.join(WDIR, n + ".v"), wout + "/")
# port check against the Chisel declarations
mems = [f for f in glob.glob(gen + "/*.top.mems.v") + glob.glob(GC + "/*.mems.v")]
assert mems, "no top.mems.v for the port check"
ref = {}
for f in mems:
    ref.update(pd.parse_modules(open(f, errors="ignore").read()))
nport = 0
for n in wfiles:
    mine = pd.parse_modules(open(os.path.join(WDIR, n + ".v")).read()).get(n)
    theirs = ref.get(n)
    if mine is None or theirs is None or mine != theirs:
        sys.exit("FAIL: wrapper %s/%s ports differ from the elaborated %s declaration: wrapper=%s elaborated=%s" % (wdesign, n, cfg, mine, theirs))
    nport += len(mine)
    print("PORTS-MATCH %s/%s: %d ports identical (name, direction, width) with %s" % (wdesign, n, len(mine), os.path.basename(mems[0])))

# conf (mems.conf) for depth/width/ports per macro
conf = {}
for l in open(glob.glob(gen + "/*.top.mems.conf")[0]):
    p = l.split()
    if len(p) >= 8 and p[0] == "name":
        conf[p[1]] = dict(depth=int(p[3]), width=int(p[5]), ports=p[7], mask=(int(p[9]) if len(p) > 9 else 0))
# banks inside each wrapper
banks = {}
for n in wfiles:
    t = open(os.path.join(WDIR, n + ".v")).read()
    cnt = {}
    for m in re.finditer(r'^\s*(bk_\w+)\s+(\w+)\s*\(', t, re.M):
        cnt[m.group(1)] = cnt.get(m.group(1), 0) + 1
    banks[n] = cnt
    assert cnt, "wrapper %s contains no bank cells" % n

# copy reachable defined modules (whole files)
copied = set()
for m, f in sorted(reach.items()):
    if f and f not in copied and m in mod_text:
        shutil.copy(f, rtl + "/" + os.path.basename(f)); copied.add(f)
fl = sorted(os.path.basename(f) for f in copied)
with open(out + "/filelist.f", "w") as fo:
    fo.write("".join(x + "\n" for x in fl))
extra = {m for f in copied for m in mod_text if mod_file[m] == f} - set(reach)
print("files copied:", len(copied), "extra (unreachable) modules co-located in copied files:", sorted(extra))

rows, insts = [], []


def walk(mod, path, rel):
    for n, t in children(mod):
        p = rel + [n]
        if t in ext:
            rows.append((path + "." + n, t))
        elif t in mod_text:
            insts.append("/".join(p))
            walk(t, path + "." + n, p)


walk("Gemmini", "Gemmini", [])
print("MACRO INSTANCES under Gemmini: %d" % len(rows))
byt = {}
with open(out + "/macro_instances.txt", "w") as fo:
    for p, t in rows:
        c = conf[t]
        s = "%s | %s | %dx%d | %s | mask_gran %d | banks %s" % (p, t, c["depth"], c["width"], c["ports"], c["mask"], ",".join("%s*%d" % kv for kv in sorted(banks[t].items())))
        print(s); fo.write(s + "\n")
        byt[t] = byt.get(t, 0) + 1
bank_total = {}
for t, n in byt.items():
    c = conf[t]
    print("SUMMARY %s: %d instances x %d bits = %.1f KiB; banks per instance %s" % (t, n, c["depth"] * c["width"], n * c["depth"] * c["width"] / 8192, banks[t]))
    for b, k in banks[t].items():
        bank_total[b] = bank_total.get(b, 0) + n * k
print("BANK CELLS total:", bank_total, "sum", sum(bank_total.values()))
# P0b inventory (macros.json) for comparison
inv = json.load(open(os.path.join(REPO, "hw/power/lib/freepdk45/macros.json")))["designs"].get(wdesign, [])
inv_inst = {e["ext"]: e["instances"] for e in inv}
if inv_inst != byt:
    print("INVENTORY-DIFF: P0b macros.json %s != elaborated %s" % (inv_inst, byt))
    inv_ok = False
else:
    print("INVENTORY-MATCH: P0b macros.json instance counts %s == elaborated" % inv_inst)
    inv_ok = True
json.dump(dict(rows=rows, conf={t: conf[t] for t in byt}, banks=banks, bank_total=bank_total, per_ext=byt, inventory_match=inv_ok,
               rtl_files=len(fl), modules=len([m for m in reach if m in mod_text]), wrappers=wfiles), open(out + "/extract.json", "w"), indent=1)

# groups.tcl for joules_gemmini.tcl: every instance down to depth 2 below Gemmini (power_inst_<top>__<path>.rpt), plus the macro-wrapper instances
tops = {}
for p in insts:
    parts = p.split("/")
    if len(parts) <= 2:
        tops.setdefault(parts[0], []).append(p)
for p, t in rows:
    q = p.split(".", 1)[1].replace(".", "/")
    tops.setdefault(q.split("/")[0], []).append(q)
with open(out + "/groups.tcl", "w") as fo:
    fo.write("# generated by logs/m7p1-extract.py: instances below Gemmini (depth <= 2) and the SRAM wrapper instances\nset groups {\n")
    for g in sorted(tops):
        fo.write("  %s {%s}\n" % (re.sub(r'\W', '_', g), " ".join(sorted(set(tops[g])))))
    fo.write("}\n")
print("groups.tcl:", sum(len(set(v)) for v in tops.values()), "instances in", len(tops), "groups")
print("EXTRACT-OK rtl_files=%d macros=%d banks=%d" % (len(fl), len(rows), sum(bank_total.values())))
