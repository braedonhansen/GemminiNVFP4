source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
cd generators/gemmini/software/gemmini-rocc-tests/build_spike/bareMetalC
ls | grep fp4 | grep baremetal
for t in $(ls | grep 'matmul_tiled_fp4.*-baremetal$'); do
  s=$(date +%s)
  timeout 900 spike --extension=gemmini ./$t > ~/nvfp4-logs/m5-spike-$t.log 2>&1; rc=$?
  echo "$t rc=$rc $(( $(date +%s)-s ))s $(grep -c PASSED ~/nvfp4-logs/m5-spike-$t.log) PASSED-lines; $(grep -i -E 'cycle|passed|failed' ~/nvfp4-logs/m5-spike-$t.log | head -3 | tr '\n' '|')"
done
