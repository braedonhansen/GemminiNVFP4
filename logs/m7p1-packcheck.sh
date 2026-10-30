#!/bin/bash
# usage: m7p1-packcheck.sh <job>   -- re-extracts the job tarball into a scratch dir; verifies the MANIFEST hashes, that the flow scripts equal the repo's,
# that the libraries and wrappers are the repo's kit files, and that the VCD is a non-empty Gemmini-scope waveform. Prints counts.
J=$1; R=/mnt/c/Users/braed/gemmini-nvfp4; K=$R/hw/power/lib/freepdk45
T=$HOME/nvfp4-logs/m7p1/jobs/$J.tar.gz
[ -s $T ] || { echo "PACKCHECK-FAIL no tarball $T"; exit 1; }
D=$(mktemp -d $HOME/nvfp4-logs/m7p1/jobs/chk.XXXX); tar xzf $T -C $D; cd $D
N=$(wc -l < MANIFEST); OK=$(sha256sum -c MANIFEST 2>&1 | grep -c ": OK"); BAD=$(sha256sum -c MANIFEST 2>&1 | grep -vc ": OK")
echo "manifest entries=$N ok=$OK bad=$BAD"
F=0
for f in genus_gemmini.tcl joules_gemmini.tcl run.csh; do cmp -s $f $R/hw/power/$f || { echo "differs from repo: $f"; F=1; }; done
echo "scripts equal to hw/power: $([ $F = 0 ] && echo yes || echo NO)"
if [ -d lib ]; then
  cmp -s lib/nangate45/NangateOpenCellLibrary_typical.lib $K/nangate45/NangateOpenCellLibrary_typical.lib || { echo "nangate lib differs"; F=1; }
  NB=0; for b in lib/banks/*_pj.lib; do cmp -s $b $K/openram/banks/$(basename $b) || { echo "bank lib differs: $b"; F=1; }; NB=$((NB+1)); done
  for w in wrappers/*.v; do WD=$(grep -l . $K/wrappers/*/$(basename $w) | while read x; do cmp -s $w $x && echo $x; done | head -1); [ -n "$WD" ] || { echo "wrapper not from the kit: $w"; F=1; }; done
  echo "libs: nangate + $NB bank libs equal to the kit; wrappers: $(ls wrappers | wc -l) files all from one kit folder: $(for w in wrappers/*.v; do for x in $K/wrappers/*/$(basename $w); do cmp -s $w $x && basename $(dirname $x); done; done | sort | uniq -c | tr '\n' ' ')"
fi
gzip -t act/kernel.vcd.gz && echo "vcd.gz integrity ok"
zcat act/kernel.vcd.gz | head -c 4000000 > /tmp/vhead.txt
echo "vcd head: $(head -c 30 /tmp/vhead.txt | head -1) ... \$var count in first 4 MB: $(grep -c '^\$var\|^ *\$var' /tmp/vhead.txt)"
grep -m1 "^#" /tmp/vhead.txt
grep -E "window|clock period|periods_ps|VCDCHECK|vars_outside" act/vcdcheck.txt | head -4
[ "$N" -gt 100 ] && [ "$OK" = "$N" ] && [ "$BAD" = 0 ] && [ $F = 0 ] && echo PACKCHECK-PASS || echo PACKCHECK-FAIL
cd ~; rm -rf $D
