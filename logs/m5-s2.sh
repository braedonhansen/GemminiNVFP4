source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
which riscv64-unknown-elf-gcc spike verilator
cd generators/gemmini
git status --short | head -3; git log -1 --format=%h
git fetch origin gemmini-mx-cleanup 2>&1 | tail -2
git checkout 266c593f 2>&1 | tail -2
git submodule update --init mxgen software/gemmini-rocc-tests software/libgemmini 2>&1 | tail -8
git log -1 --format=%H; git submodule status
