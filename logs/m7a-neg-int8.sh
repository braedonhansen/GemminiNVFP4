# negative control: flip one expected INT32 (C0[100]) in a copy of the INT8 data header, rebuild under another name, Spike must report exactly 1 mismatch
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh
W=~/nvfp4-logs/m7a; R=/mnt/c/Users/braed/gemmini-nvfp4
cd $W/src
cp m7a_int8_data.h m7a_intneg_data.h
python3 - <<'PY'
import re
p='m7a_intneg_data.h'; t=open(p).read()
i=t.index('static const int32_t C0[')
j=t.index('{',i)+1
k=t.index('}',j)
vals=t[j:k].replace('\n',' ').split(',')
vals=[v.strip() for v in vals if v.strip()]
vals[100]=str(int(vals[100])+1)
t=t[:j]+'\n'+',\n'.join(vals)+'\n'+t[k:]
open(p,'w').write(t); print('mutated C0[100]')
PY
sed 's/m7a_int8_data.h/m7a_intneg_data.h/' $R/hw/tests/m7a_int8.c > m7a_intneg.c
RT=~/chipyard/generators/gemmini/software/gemmini-rocc-tests; BENCH=$RT/riscv-tests/benchmarks/common
riscv64-unknown-elf-gcc -DPREALLOCATE=1 -DMULTITHREAD=1 -mcmodel=medany -std=gnu99 -O2 -ffast-math -fno-common -fno-builtin-printf -fno-tree-loop-distribute-patterns -march=rv64gc -Wa,-march=rv64gc -lm -lgcc -I$RT/riscv-tests -I$RT/riscv-tests/env -I$RT -I$BENCH -DID_STRING= -DPRINT_TILE=0 -nostdlib -nostartfiles -static -T $BENCH/test.ld -DBAREMETAL=1 m7a_intneg.c -o $W/bin/m7a_intneg $BENCH/*.c $BENCH/*.S -lm 2>&1 | grep -v RWX
spike --extension=gemmini $W/bin/m7a_intneg 2>&1 | grep -E "case 0|mismatches|got"; echo "spike rc=${PIPESTATUS[0]}"
