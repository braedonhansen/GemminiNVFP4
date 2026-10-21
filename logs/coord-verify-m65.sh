# Coordinator check for M6.5
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh >/dev/null 2>&1
G=~/chipyard-mx/generators/gemmini; T=$G/software/gemmini-rocc-tests
echo "== branches"; git -C $G log --oneline -1; git -C $G status --short | head -3; git -C $G/software/libgemmini log --oneline -1
for t in nvfp4_mt_m64n64k128 nvfp4_mt_m32n96k64 nvfp4_mt_m96n32k256 nvfp4_mt_m64n64k512; do
  B=$(find $T -path '*build_spike*' -name "$t-baremetal" | head -1); [ -z "$B" ] && { echo "MISSING spike binary $t"; continue; }
  echo "spike $t: $(spike --extension=gemmini_nvfp4 $B 2>&1 | grep -i mismatch)"
done
cd sims/verilator
for t in nvfp4_mt_m64n64k512 nvfp4_mt_m96n32k256; do
  B=$(find $T -path '*build_mx_rocket*' -name "$t-baremetal" | head -1)
  make CONFIG=NvFp4GemminiRocketConfig LOADMEM=1 TIMEOUT_CYCLES=200000000 run-binary BINARY=$B > ~/nvfp4-logs/coord-m65-$t.log 2>&1
  echo "verilator $t rc=$?: $(grep -i mismatch ~/nvfp4-logs/coord-m65-$t.log | tail -1)"
done
