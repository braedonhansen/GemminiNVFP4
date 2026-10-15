source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null 2>&1
df -h ~ | tail -1; free -g | head -2
which spike
spike --extension=gemmini ~/chipyard/generators/gemmini/software/gemmini-rocc-tests/build/bareMetalC/nvfp4_v0-baremetal 2>&1 | tail -5; echo EXIT=$?
