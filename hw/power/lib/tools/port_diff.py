#!/usr/bin/env python3
"""Diff the port lists of generated wrapper modules against the Chisel/firtool SRAM
black-box declarations in <config>.top.mems.v (M7.P0b).

usage: port_diff.py WRAPPER_DIR DESIGN MEMS_V [MEMS_V ...]
Fails (exit 1) if zero modules were compared, or any port name/direction/width differs.
"""
import re, sys, os


def parse_modules(text):
    """Return {module: {port: (dir, width)}} for every 'module X(' ... ');' header."""
    mods = {}
    for m in re.finditer(r"^module\s+(\w+)\s*\((.*?)\);", text, re.S | re.M):
        name, body = m.group(1), m.group(2)
        ports = {}
        for line in body.split(","):
            line = re.sub(r"//.*", "", line).strip()
            mm = re.match(r"(input|output|inout)\s*(?:wire|reg)?\s*(?:\[(\d+):(\d+)\])?\s*(\w+)$", line)
            if not mm:
                continue
            d, hi, lo, n = mm.groups()
            w = (int(hi) - int(lo) + 1) if hi is not None else 1
            ports[n] = (d, w)
        mods[name] = ports
    return mods


def main():
    wdir, design = sys.argv[1], sys.argv[2]
    ref = {}
    for f in sys.argv[3:]:
        ref.update(parse_modules(open(f, errors="ignore").read()))
    d = os.path.join(wdir, design)
    compared = bad = 0
    for fn in sorted(os.listdir(d)):
        if not fn.endswith(".v"):
            continue
        name = fn[:-2]
        mine = parse_modules(open(os.path.join(d, fn)).read()).get(name)
        theirs = ref.get(name)
        if mine is None or theirs is None:
            print("MISSING  %s/%s: wrapper=%s reference=%s" % (design, name, mine is not None, theirs is not None))
            bad += 1
            continue
        compared += 1
        if mine == theirs:
            print("MATCH    %s/%s: %d ports identical (name, dir, width)" % (design, name, len(mine)))
        else:
            bad += 1
            print("DIFFER   %s/%s" % (design, name))
            for p in sorted(set(mine) | set(theirs)):
                if mine.get(p) != theirs.get(p):
                    print("   %s: wrapper=%s reference=%s" % (p, mine.get(p), theirs.get(p)))
    print("SUMMARY %s: compared=%d bad=%d" % (design, compared, bad))
    if compared == 0 or bad:
        sys.exit(1)


if __name__ == "__main__":
    main()
