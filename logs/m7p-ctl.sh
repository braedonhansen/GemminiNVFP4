source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null 2>&1
cd ~/nvfp4-logs/m7p/int8/rtl
grep -v sram_stubs ../filelist.f > /tmp/fl_nostub.f
verilator --lint-only -Wno-fatal --top-module Gemmini -f /tmp/fl_nostub.f 2>&1 | grep -c '%Error'
