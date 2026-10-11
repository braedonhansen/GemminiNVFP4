source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh
cd sims/verilator
B=../../generators/gemmini/software/gemmini-rocc-tests/build/bareMetalC
ls simulator-chipyard.harness-GemminiRocketConfig* | head -3
rm -f ~/nvfp4-logs/m4-verilator.done
nohup bash -c "date +%s > ~/nvfp4-logs/m4-verilator.start; make CONFIG=GemminiRocketConfig TIMEOUT_CYCLES=20000000 run-binary-fast BINARY=$B/nvfp4_v0-baremetal > ~/nvfp4-logs/m4-verilator.log 2>&1; echo EXIT=\$? > ~/nvfp4-logs/m4-verilator.done; date +%s >> ~/nvfp4-logs/m4-verilator.done" >/dev/null 2>&1 &
sleep 2; echo started
