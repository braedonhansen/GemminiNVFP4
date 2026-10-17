#!/bin/bash
# Usage: synth_metrics.sh <outdir> <top> <verilog files...>
# Prints: top,aig_ands,aig_nots,gates_cmos2,depth_ltp,depth_and_levels
# Fixed script (brief step 4):
#   AIG:   read_verilog; synth -flatten -top X; abc -g AND; stat ; ltp -noff
#   gates: read_verilog; synth -flatten -top X; abc -g cmos2; stat
out=$1; top=$2; shift 2
mkdir -p "$out"
yosys -q -l "$out/${top}_aig.log" -p "read_verilog ${RV_OPTS:-} $*; synth -flatten -top $top; abc -g AND; opt_clean; tee -o $out/${top}_aig.stat stat; tee -o $out/${top}_ltp.txt ltp -noff; write_json $out/${top}_aig.json" >/dev/null 2>&1 || { echo "$top,ERR"; exit 1; }
yosys -q -l "$out/${top}_cmos.log" -p "read_verilog ${RV_OPTS:-} $*; synth -flatten -top $top; abc -g cmos2; opt_clean; tee -o $out/${top}_cmos.stat stat" >/dev/null 2>&1 || { echo "$top,ERR"; exit 1; }
ands=$(grep -E '\$_AND_' "$out/${top}_aig.stat" | awk '{print $1}' | head -1); ands=${ands:-0}
nots=$(grep -E '\$_NOT_' "$out/${top}_aig.stat" | awk '{print $1}' | head -1); nots=${nots:-0}
gates=$(awk '/^ +[0-9]+ +\$_/ {n+=$1} END {print n+0}' "$out/${top}_cmos.stat")
depth=$(grep -oE 'length=[0-9]+' "$out/${top}_ltp.txt" | head -1 | cut -d= -f2)
andlev=$(python3 "$(dirname "$0")/and_levels.py" "$out/${top}_aig.json" "$top")
echo "$top,$ands,$nots,$gates,$depth,$andlev"
