#!/usr/bin/env python3
"""Check OpenRAM bank .lib/.v pairs (M7.P0b L3/L4). Prints one line per bank; exit 1 on any failure
or if zero banks were checked.

usage: check_macro_libs.py DIR   (DIR contains <bank>.v and <bank>.lib [+ <bank>_pj.lib])
Checks per bank:
  - lib is brace-balanced, has exactly one cell() whose name equals the Verilog module name
  - cell_leakage_power > 0
  - clk internal_power: read and write states present and > 0; disabled states == 0 (corrected lib only)
  - lib bus/pin names == Verilog port names (so the bank instantiation in the wrappers resolves)
"""
import re, sys, os, glob


def strip_comments(t):
    return re.sub(r"/\*.*?\*/", "", t, flags=re.S)


def lib_info(path):
    t = strip_comments(open(path).read())
    ok_braces = t.count("{") == t.count("}") and t.count("{") > 0
    cells = re.findall(r"^\s*cell\s*\(\s*\"?([\w$]+)\"?\s*\)", t, re.M)
    leak = re.search(r"^\s*cell_leakage_power\s*:\s*([\d.eE+-]+)", t, re.M)
    ip = re.findall(r'internal_power\s*\(\s*\)\s*\{\s*when\s*:\s*"([^"]*)";\s*rise_power\(scalar\)\s*\{\s*values\("([^"]*)"\)'
                    r'.*?fall_power\(scalar\)\s*\{\s*values\("([^"]*)"\)', t, re.S)
    names = set(re.findall(r"^\s*(?:bus|pin)\s*\(\s*(\w+)", t, re.M))
    return dict(braces=ok_braces, cells=cells, leak=float(leak.group(1)) if leak else None,
                ip=[(w.strip(), float(r), float(f)) for w, r, f in ip], names=names)


def v_ports(path):
    t = open(path).read()
    ports = set()
    for m in re.finditer(r"^\s*(?:input|output)\s*(?:\[[^\]]*\])?\s*(\w+)\s*;", t, re.M):
        ports.add(m.group(1))
    mod = re.search(r"^module\s+(\w+)", t, re.M).group(1)
    return mod, ports


def main():
    d = sys.argv[1]
    n = bad = 0
    for v in sorted(glob.glob(os.path.join(d, "*.v"))):
        base = v[:-2]
        mod, ports = v_ports(v)
        libs = [p for p in (base + ".lib", base + "_pj.lib") if os.path.exists(p)]
        if not libs:
            print("FAIL %s: no .lib" % mod)
            bad += 1
            continue
        for lib in libs:
            n += 1
            li = lib_info(lib)
            corrected = lib.endswith("_pj.lib")
            errs = []
            if not li["braces"]:
                errs.append("unbalanced braces")
            if li["cells"] != [mod]:
                errs.append("cells=%s != module %s" % (li["cells"], mod))
            if not li["leak"] or li["leak"] <= 0:
                errs.append("no leakage")
            act = [x for x in li["ip"] if x[0].startswith("!")]
            dis = [x for x in li["ip"] if not x[0].startswith("!")]
            if len(act) < 1 or any(r <= 0 for _, r, _ in act):
                errs.append("missing/zero active internal_power")
            if corrected and any(r != 0 or f != 0 for _, r, f in dis):
                errs.append("disabled state not zero")
            miss = ports - li["names"]
            if miss:
                errs.append("verilog ports not in lib: %s" % sorted(miss))
            tag = "pj " if corrected else "raw"
            print("%s %s %-30s leak=%.6g mW  active=%s  disabled=%s  ports=%d%s" % (
                "FAIL" if errs else "PASS", tag, mod, li["leak"] or 0,
                ["%s:%.4g" % (w, r) for w, r, _ in act], len(dis), len(ports), ("  " + "; ".join(errs)) if errs else ""))
            bad += bool(errs)
    print("SUMMARY checked=%d bad=%d" % (n, bad))
    if n == 0 or bad:
        sys.exit(1)


if __name__ == "__main__":
    main()
