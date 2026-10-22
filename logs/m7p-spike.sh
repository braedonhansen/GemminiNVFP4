# Runs the three P0.3 test variants in Spike (stock tree, libgemmini): base PASS, full-reference PASS (4096 compared), corrupt FAIL.
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null 2>&1
mkdir -p ~/nvfp4-logs/m7p/runs
for V in base full corrupt; do
  S=$(date +%s)
  timeout 1200 spike --extension=gemmini ~/nvfp4-logs/m7p/test/bin/m7p_int8_$V > ~/nvfp4-logs/m7p/runs/spike_$V.log 2>&1; rc=$?
  echo "variant=$V rc=$rc secs=$(( $(date +%s) - S ))"; grep -E "outputs checked|full reference|direct rows" ~/nvfp4-logs/m7p/runs/spike_$V.log
done
