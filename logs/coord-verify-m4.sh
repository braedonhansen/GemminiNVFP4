source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null 2>&1
D=~/chipyard/generators/gemmini/software/gemmini-rocc-tests
R=/mnt/c/Users/braed/gemmini-nvfp4
cmp $R/hw/tests/nvfp4_v0_data.h $D/bareMetalC/nvfp4_v0_data.h && echo HEADER_SAME
cmp $R/hw/tests/nvfp4_v0.c $D/bareMetalC/nvfp4_v0.c && echo SRC_SAME
git -C ~/chipyard/generators/gemmini status --short | head
spike --extension=gemmini $D/build/bareMetalC/nvfp4_v0-baremetal 2>&1 | tail -8; echo SPIKE_EXIT=${PIPESTATUS[0]}
