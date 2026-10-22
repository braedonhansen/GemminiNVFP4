source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh
B=~/chipyard/generators/gemmini/software/gemmini-rocc-tests/build/bareMetalC
timeout 300 spike --extension=gemmini $B/mvin_mvout_acc_full-baremetal; echo "EXIT=$?"
timeout 300 spike --extension=gemmini $B/nvfp4_v0-baremetal; echo "EXIT=$?"
