# usage: m7p1-vcd.sh <job>   -- window from pass1 (no-dump run), then pass 2 (same binary, dump only the window), then VCD checks
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m7p1-env.sh
m7p1_design $1 || exit 2
m7p1_shell $TREE
A=$W/act; mkdir -p $A
python3 $R/logs/m7p-window.py $W/runs/pass1.log $A || { echo "WINDOW-FAIL"; exit 1; }
S=$(grep ^start_cycle $A/window.txt | cut -d= -f2); E=$(grep ^end_cycle $A/window.txt | cut -d= -f2)
[ -n "$S" ] && [ -n "$E" ] || { echo "no window"; exit 2; }
echo "window $S..$E"
rm -f $A/kernel.vcd
bash $R/logs/m7p1-sim-run.sh $JOB base pass2 +m7p-start=$S +m7p-end=$E +vcdfile=$A/kernel.vcd
ls -la $A
INST=$(cat $W/gemmini_inst.txt)
ROOT=TOP.TestDriver.testHarness.chiptop0.system.tile_prci_domain.element_reset_domain_rockettile.$INST
python3 $R/logs/m7p-vcdcheck.py $A/kernel.vcd $ROOT $A | tee $A/vcdcheck_raw.txt | tail -14
grep -q "VCDCHECK PASS" $A/vcdcheck_raw.txt && echo "VCD-OK" || echo "VCD-FAIL"
