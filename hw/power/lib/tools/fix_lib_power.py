#!/usr/bin/env python3
"""Post-process an OpenRAM analytical .lib so Genus/Joules read per-access energy correctly (M7.P0b).

What OpenRAM's analytical (netlist_only) model writes, and why it needs fixing:
  1. clk-pin internal_power values are an *average power in mW at the technology's default event
     frequency* (spice["default_event_frequency"] = 100 MHz), not an energy. Liberty energy units here
     are V*mA*ns = pJ, so the tools would read 4.9 as 4.9 pJ while the model means 4.9 mW / 100 MHz
     = 49 pJ. Fix: E_pJ = value_mW / f_GHz  (f = 0.1 GHz, i.e. x10).
  2. All four 'when' states (read, write, and both disabled states csb0=1 / csb1=1) get the same value,
     so a deselected bank would be charged a full access. Fix: disabled states (csb high) get 0.
  3. rise_power and fall_power are equal, so one cycle would be charged twice. Fix: the full per-access
     energy goes on rise_power (one clock rise per cycle) and fall_power is 0.
Leakage and every timing table are left as OpenRAM wrote them.

usage: fix_lib_power.py IN.lib OUT.lib [--freq-ghz 0.1]
Prints the counts of blocks changed; exits 1 if nothing was changed.
"""
import re, sys

BLOCK = re.compile(r'(internal_power\s*\(\s*\)\s*\{\s*when\s*:\s*"([^"]*)";\s*'
                   r'rise_power\(scalar\)\s*\{\s*values\("([^"]*)"\);\s*\}\s*'
                   r'fall_power\(scalar\)\s*\{\s*values\("([^"]*)"\);\s*\}\s*\})', re.S)


def main():
    src, dst = sys.argv[1], sys.argv[2]
    fghz = 0.1
    if "--freq-ghz" in sys.argv:
        fghz = float(sys.argv[sys.argv.index("--freq-ghz") + 1])
    text = open(src).read()
    stats = {"active": 0, "disabled": 0}
    energies = []

    def repl(m):
        when, rise, fall = m.group(2), float(m.group(3)), float(m.group(4))
        disabled = re.match(r"\s*c?sb\d", when) is not None and not when.strip().startswith("!")
        if disabled:
            stats["disabled"] += 1
            new_r, new_f = 0.0, 0.0
        else:
            stats["active"] += 1
            new_r, new_f = rise / fghz, 0.0   # pJ per access on the rising edge
            energies.append((when.strip(), new_r))
        blk = m.group(1)
        blk = re.sub(r'(rise_power\(scalar\)\s*\{\s*values\(")[^"]*("\))', lambda k: "%s%.6e%s" % (k.group(1), new_r, k.group(2)), blk)
        blk = re.sub(r'(fall_power\(scalar\)\s*\{\s*values\(")[^"]*("\))', lambda k: "%s%.6e%s" % (k.group(1), new_f, k.group(2)), blk)
        return blk

    out = BLOCK.sub(repl, text)
    out = out.replace("library (", "/* M7.P0b: clk internal_power converted mW@100MHz -> pJ/access, disabled states zeroed,\n   fall_power zeroed (see hw/power/lib/tools/fix_lib_power.py) */\nlibrary (", 1)
    n = stats["active"] + stats["disabled"]
    print("%s: internal_power blocks changed=%d (active=%d disabled=%d)" % (src, n, stats["active"], stats["disabled"]))
    for w, e in energies:
        print("   when %-22s -> %.4f pJ/access" % (w, e))
    if n == 0:
        print("FAIL: no internal_power blocks matched; nothing was fixed")
        sys.exit(1)
    open(dst, "w", newline="\n").write(out)


if __name__ == "__main__":
    main()
