source ~/miniforge3/etc/profile.d/conda.sh
ls ~/chipyard-mx/.conda-lock-env | head; ls ~/chipyard-mx/.conda-lock-env/bin | grep -c .; ~/chipyard-mx/.conda-lock-env/bin/conda-lock --version
cd ~/chipyard; ls .conda-env/bin | head -3; ls conda-reqs/conda-lock-reqs/ | head; grep -n sysroot conda-reqs/riscv-tools.yaml
cd ~/chipyard-mx; git describe --tags; git status --short | head
~/miniforge3/bin/conda --version
source ~/chipyard/env.sh >/dev/null 2>&1; spike --extension=gemmini ~/chipyard/generators/gemmini/software/gemmini-rocc-tests/build/bareMetalC/nvfp4_v0-baremetal 2>&1 | tail -5; echo rc=$?
