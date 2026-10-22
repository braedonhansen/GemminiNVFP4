# Coordinator re-check of M7.P0 (stock INT8 power job package).
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null
J=~/nvfp4-logs/m7p/jobs/int8-stock-a.tar.gz; X=~/nvfp4-logs/m7p-coord/job; rm -rf $X; mkdir -p $X; cd $X
ls -l $J; tar xzf $J; echo "files: $(find . -type f | wc -l)"; [ -f MANIFEST ] && sha256sum -c MANIFEST 2>/dev/null | grep -c ": OK"
echo "== lint"; verilator --lint-only -Wno-fatal --top-module Gemmini -f filelist.f 2>&1 | grep -c "%Error"; grep -c . filelist.f
echo "== stubs"; grep -l "^module mem_ext\b\|^module mem_0_ext\b" -r . | head; grep -rh "^\s*mem_ext \|^\s*mem_0_ext " --include=*.sv . | wc -l
echo "== vcd"; zcat act/kernel.vcd.gz | head -c 4000 | grep -E "timescale|scope module" | head -6
zcat act/kernel.vcd.gz | grep -c '^#' 
echo "== params"; grep -E "setenv (CLK|LIB|TOP|WIN)|setenv" run.csh | head -12
