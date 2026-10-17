#!/usr/bin/env python3
"""AND-level depth of a Yosys write_json netlist of $_AND_/$_NOT_ cells (inverters cost 0)."""
import json, sys
sys.setrecursionlimit(100000)
d = json.load(open(sys.argv[1]))["modules"][sys.argv[2]]
drv = {}
for c in d["cells"].values():
    t = c["type"]
    if t not in ("$_AND_", "$_NOT_"):
        continue
    ins = [b for k, v in c["connections"].items() if c["port_directions"][k] == "input" for b in v]
    outs = [b for k, v in c["connections"].items() if c["port_directions"][k] == "output" for b in v]
    for o in outs:
        drv[o] = (t, ins)
memo = {}
def lev(b):
    if not isinstance(b, int) or b not in drv:
        return 0
    if b in memo:
        return memo[b]
    t, ins = drv[b]
    memo[b] = (1 if t == "$_AND_" else 0) + max(lev(i) for i in ins)
    return memo[b]
outs = [b for p in d["ports"].values() if p["direction"] == "output" for b in p["bits"]]
print(max(lev(b) for b in outs))
