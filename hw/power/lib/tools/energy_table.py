#!/usr/bin/env python3
"""Per-bank and per-macro energy/leakage table from the corrected (_pj) OpenRAM libs (M7.P0b L4).

usage: energy_table.py LIBDIR OUT.md
Reads LIBDIR/<bank>_pj.lib, composes the wrapper macros from gen_wrappers.DESIGNS, prints a markdown
table (also written to OUT.md). Fails if no bank lib was read or any energy/leakage is <= 0.
E_macro(read)  = (#banks across the width) x E_bank_read   (one bank row selected per access)
E_macro(write) = (#banks across the width) x E_bank_write
Leak_macro     = (#banks deep x #banks wide) x Leak_bank
"""
import os, re, sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_wrappers as G


def bank_numbers(path):
    t = open(path).read()
    t = re.sub(r"/\*.*?\*/", "", t, flags=re.S)
    leak = float(re.search(r"^\s*cell_leakage_power\s*:\s*([\d.eE+-]+)", t, re.M).group(1))  # mW
    # clock pins: pin(clk0) / pin(clk1) groups
    en = {}
    for m in re.finditer(r"pin\((clk\d)\)\s*\{(.*?)\n    \}\n", t, re.S):
        port = m.group(1)
        for w, r in re.findall(r'internal_power\(\)\s*\{\s*when\s*:\s*"([^"]*)";\s*rise_power\(scalar\)\s*\{\s*values\("([^"]*)"\)', m.group(2), re.S):
            if w.strip().startswith("!"):
                en[(port, w.strip())] = float(r)
    return leak, en


def main():
    libdir, out = sys.argv[1], sys.argv[2]
    banks = {}
    L = []
    L.append("| Bank | bits | leakage (uW) | write E (pJ) | read E (pJ) | write pJ/bit | read pJ/bit | leak nW/bit |")
    L.append("|---|---|---|---|---|---|---|---|")
    seen = set()
    for des, ents in G.DESIGNS.items():
        for e in ents:
            b = e["bank"]
            if b[0] in seen:
                continue
            seen.add(b[0])
            p = os.path.join(libdir, b[0] + "_pj.lib")
            if not os.path.exists(p):
                print("missing", p)
                continue
            leak, en = bank_numbers(p)
            bits = b[1] * b[2]
            if any(k[0] == "clk1" for k in en):   # 1w1r: clk0 = write port, clk1 = read port
                ew = max(v for k, v in en.items() if k[0] == "clk0")
                er = max(v for k, v in en.items() if k[0] == "clk1")
            else:                                 # 1rw: web0 low = write, high = read
                ew = [v for k, v in en.items() if k[1].endswith("!web0")][0]
                er = [v for k, v in en.items() if k[1].endswith("& web0") and not k[1].endswith("!web0")][0]
            assert leak > 0 and ew > 0 and er > 0, (b[0], leak, ew, er)
            banks[b[0]] = dict(leak_uw=leak * 1e3, ew=ew, er=er, bits=bits, depth=b[1], width=b[2])
            L.append("| %s | %d | %.2f | %.2f | %.2f | %.3f | %.3f | %.3f |" % (
                b[0], bits, leak * 1e3, ew, er, ew / b[2], er / b[2], leak * 1e6 / bits))
    if not banks:
        print("FAIL: no bank libs read")
        sys.exit(1)
    L.append("")
    L.append("| Design | Macro (ext) | Shape | Ports | Mask | Banks (deep x wide) | Instances | write E (pJ) | read E (pJ) | leakage / instance (uW) | leakage total (uW) | derived |")
    L.append("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for des, ents in G.DESIGNS.items():
        tot_leak = 0.0
        for e in ents:
            b = e["bank"]
            if b[0] not in banks:
                continue
            nd, nw = e["depth"] // b[1], e["width"] // b[2]
            k = banks[b[0]]
            lk = nd * nw * k["leak_uw"]
            tot_leak += lk * e["count"]
            L.append("| %s | %s | %dx%d | %s | %s | %dx%d | %d | %.1f | %.1f | %.1f | %.1f | %s |" % (
                des, e["name"], e["depth"], e["width"], "1RW" if e["kind"] == "rw" else "1W+1R",
                e["mask_gran"] or "-", nd, nw, e["count"], nw * k["ew"], nw * k["er"], lk, lk * e["count"],
                "yes" if e["derived"] else "no"))
        L.append("| %s | **total SRAM leakage** | | | | | | | | | **%.1f** | |" % (des, tot_leak))
    txt = "\n".join(L) + "\n"
    open(out, "w", newline="\n").write(txt)
    print(txt)


if __name__ == "__main__":
    main()
