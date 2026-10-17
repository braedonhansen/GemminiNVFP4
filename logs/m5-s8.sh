source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
cd generators/gemmini/software/gemmini-rocc-tests
H=include/matmul_fp4_64x64.h; T=matmul_tiled_fp4_64x64
sed -n 259p $H | cut -c1-80
cp $H $HOME/nvfp4-logs/m5-$T.h.orig; sha256sum $H
# corrupt first value on line 259 (toggle low bit of first hex literal)
python3 - <<'PY'
import re,os
p="include/matmul_fp4_64x64.h"
L=open(p).read().split("\n")
m=re.search(r"0x([0-9a-fA-F]+)",L[258])
v=int(m.group(1),16)^1
L[258]=L[258][:m.start()]+("0x%0*x"%(len(m.group(1)),v))+L[258][m.end():]
open(p,"w").write("\n".join(L))
PY
sed -n 259p $H | cut -c1-80
git diff --stat -- $H | tail -1
rm -f build_spike/bareMetalC/$T-baremetal build_spike/bareMetalC/$T-baremetal.o; ( cd build_spike && make -j RUNNER=spike BAREMETAL_ONLY=1 2>&1 | tail -2; cd bareMetalC && ls -l $T-baremetal )
spike --extension=gemmini build_spike/bareMetalC/$T-baremetal 2>&1 | tail -3; echo "NEG rc=${PIPESTATUS[0]}"
# restore
cp $HOME/nvfp4-logs/m5-$T.h.orig $H; sha256sum $H; git diff --stat -- $H | tail -1; git status --short
rm -f build_spike/bareMetalC/$T-baremetal build_spike/bareMetalC/$T-baremetal.o; ( cd build_spike && make -j RUNNER=spike BAREMETAL_ONLY=1 2>&1 | tail -2 )
spike --extension=gemmini build_spike/bareMetalC/$T-baremetal 2>&1 | tail -3; echo "RESTORED rc=${PIPESTATUS[0]}"
