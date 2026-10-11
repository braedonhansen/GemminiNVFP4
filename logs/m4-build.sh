source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh
R=/mnt/c/Users/braed/gemmini-nvfp4
D=~/chipyard/generators/gemmini/software/gemmini-rocc-tests
cd $D
cp $R/hw/tests/nvfp4_v0.c $D/bareMetalC/nvfp4_v0.c
cp $R/hw/tests/nvfp4_v0_data.h $D/bareMetalC/nvfp4_v0_data.h
grep -q nvfp4_v0 bareMetalC/Makefile || sed -i '/^\ttemplate /a\	nvfp4_v0 \\' bareMetalC/Makefile
git status --short; git diff
cd build && make -j8 BAREMETAL_ONLY=1 bareMetalC 2>&1 | tail -20
ls -la bareMetalC/nvfp4_v0-baremetal
