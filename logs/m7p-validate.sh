# Validates the P0.3 test itself on the UNMODIFIED stock simulator build (read-only use of ~/chipyard/sims/verilator/simulator-*):
#   corrupt variant must FAIL with a nonzero exit.
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null 2>&1
SIM=$HOME/chipyard/sims/verilator/simulator-chipyard.harness-GemminiRocketConfig
mkdir -p ~/nvfp4-logs/m7p/runs; cd ~/nvfp4-logs/m7p/runs
for V in corrupt; do   # the full-reference variant is validated in Spike instead (m7p-spike.sh): 2.1M MACs on Rocket would take ~1.5 h in Verilator
  B=$HOME/nvfp4-logs/m7p/test/bin/m7p_int8_$V
  /usr/bin/time -v stdbuf -oL $SIM +permissive +dramsim +dramsim_ini_dir=$HOME/chipyard/generators/testchipip/src/main/resources/dramsim2_ini +max-cycles=80000000 +loadmem=$B +permissive-off $B </dev/null > val_$V.log 2> val_$V.err
  echo "variant=$V exit=$?"; grep -E "outputs checked|mismatch|FAILED|PASSED|full reference" val_$V.log | head -5; grep Elapsed val_$V.err
done
