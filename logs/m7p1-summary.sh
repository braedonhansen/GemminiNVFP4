#!/bin/bash
# usage: m7p1-summary.sh <job>...   one block of facts per job (for docs/M7.P1-jobs.md and the report); fails on missing facts
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m7p1-env.sh
for j in "$@"; do
  m7p1_design $j || continue
  echo "== $JOB"
  G=$TREE/generators/gemmini
  echo "gemmini commit of the RTL: $(git -C $G rev-parse --short=8 HEAD) ($(git -C $G log -1 --format=%s | cut -c1-70)); tree $(basename $TREE); config $CFG; Gemmini.sv md5 $(md5sum < $GEN/gen-collateral/Gemmini.sv | cut -c1-12), generated $(stat -c %y $GEN/gen-collateral/Gemmini.sv | cut -c1-19)"
  python3 - $W/extract.json <<'PY'
import json, sys
e = json.load(open(sys.argv[1]))
print("rtl files %d, modules %d; macro instances %d %s; bank cells %d %s; inventory match: %s" % (e["rtl_files"], e["modules"], sum(e["per_ext"].values()), e["per_ext"], sum(e["bank_total"].values()), e["bank_total"], e["inventory_match"]))
PY
  echo "RTL base:    $(grep -E 'outputs checked' $W/runs/pass1.log | tail -1)  | sim exit $(grep -c 'M7P END' $W/runs/pass1.log) end-markers"
  echo "RTL control: $(grep -E 'outputs checked' $W/runs/ctl1.log | tail -1)  | $(grep -c 'FAILED' $W/runs/ctl1.log) FAILED lines"
  echo "window: $(tr '\n' ' ' < $W/act/window.txt)"
  echo "vcd: $(stat -c %s $W/act/kernel.vcd) bytes raw; $(grep -E 'vars=|value_changes|timestamps' $W/act/vcdcheck_raw.txt | tr '\n' ' ')"
  T=$M1/jobs/$JOB.tar.gz; [ -s $T ] && echo "tarball: $T $(stat -c %s $T) bytes ($(( $(stat -c %s $T) / 1048576 )) MiB), sha256 $(sha256sum $T | cut -c1-16)"
done
