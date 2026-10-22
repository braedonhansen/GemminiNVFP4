# negative control: flip bit 0 of out_bits[0][5] in a copy of the K=1024 NVFP4 header; Spike must report 1 mismatch
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
W=~/nvfp4-logs/m7a; R=/mnt/c/Users/braed/gemmini-nvfp4; RT=~/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests; BENCH=$RT/riscv-tests/benchmarks/common
cd $W/src
python3 - <<'PY'
import re
t=open('nvfp4_m7a_k1024_data.h').read()
i=t.index('out_bits[')
j=t.index('{',i)+1
toks=re.findall(r'0x[0-9a-f]{8}u', t[j:])
tok=toks[5]
new='0x%08xu' % (int(tok[:-1],16)^1)
t=t[:j]+t[j:].replace(tok,new,1)
open('nvfp4_mneg_data.h','w').write(t); print('flipped',tok,'->',new)
PY
printf '#define E2E_DATA_HEADER "nvfp4_mneg_data.h"\n#define E2E_NAME "nvfp4_mneg"\n#include "nvfp4_e2e_mnk.c"\n' > nvfp4_mneg.c
riscv64-unknown-elf-gcc -DPREALLOCATE=1 -DMULTITHREAD=1 -mcmodel=medany -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf -fno-tree-loop-distribute-patterns -march=rv64gc -Wa,-march=rv64gc -lm -lgcc -I$RT/riscv-tests -I$RT/riscv-tests/env -I$RT -I$BENCH -DID_STRING= -DPRINT_TILE=0 -DSPIKE_SIM -nostdlib -nostartfiles -static -T $BENCH/test.ld -DBAREMETAL=1 nvfp4_mneg.c -o $W/bin/nvfp4_mneg $BENCH/*.c $BENCH/*.S -lm 2>&1 | grep -v -E "RWX|^\s|warning" | head
spike --extension=gemmini_nvfp4 $W/bin/nvfp4_mneg 2>&1 | grep -E "MISMATCH|mismatches of"; echo "spike rc=${PIPESTATUS[0]}"
