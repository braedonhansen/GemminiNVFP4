#!/bin/bash
cd ~/chipyard && source ~/miniforge3/etc/profile.d/conda.sh && source env.sh
cd sims/verilator
B=../../generators/gemmini/software/gemmini-rocc-tests/build/bareMetalC
for t in matmul conv; do
  nohup bash -c "date +%s > ~/nvfp4-logs/long-$t.start; make CONFIG=GemminiRocketConfig TIMEOUT_CYCLES=150000000 run-binary-fast BINARY=$B/$t-baremetal > ~/nvfp4-logs/long-$t.log 2>&1; echo EXIT=\$? > ~/nvfp4-logs/long-$t.done; date +%s >> ~/nvfp4-logs/long-$t.done" >/dev/null 2>&1 &
done
sleep 2; pgrep -fa "simulator-chipyard" | head
