source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null 2>&1
cd ~/nvfp4-logs/m7p/int8
(cd rtl && verilator --lint-only -Wno-fatal --top-module Gemmini -f ../filelist.f) > ../lint.log 2>&1; echo "lint exit=$?"
grep -c '%Error' ../lint.log; grep -c '%Warning' ../lint.log; grep '%Error' ../lint.log | head; grep -h '%Warning' ../lint.log | sed 's/:.*//' | sort | uniq -c
echo "defined modules: $(cat rtl/*.sv rtl/*.v 2>/dev/null | grep -c '^module ')"
