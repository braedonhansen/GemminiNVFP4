cd ~/chipyard/generators/gemmini
git log --format='%h %ad %an %s' --date=short origin/gemmini-mx-cleanup..origin/master | head
git ls-remote https://github.com/ucb-bar/esp-isa-sim.git | grep -i -E "mx|fp4|micro" | head
echo --- spike in chipyard
ls ~/chipyard/toolchains/riscv-tools/riscv-isa-sim 2>/dev/null | head -3; cd ~/chipyard/toolchains/riscv-tools/riscv-isa-sim 2>/dev/null && git log -1 --format='%h %ad %s' --date=short
which spike; ls $RISCV 2>/dev/null | head -3
echo --- flush to zero
curl -s https://api.github.com/repos/ucb-bar/libgemmini/commits?sha=876631072ecc7cc8197df5dc69c4d26bd4cd5f54\&per_page=100 | grep '"message"' | grep -i -E "flush|zero|denorm|subnormal" | head
curl -s https://raw.githubusercontent.com/ucb-bar/libgemmini/876631072ecc7cc8197df5dc69c4d26bd4cd5f54/mx_fp_math.h | grep -n -i -E "flush|subnormal|denorm" | head
