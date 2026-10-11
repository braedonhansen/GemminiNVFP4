source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh
B=~/chipyard/generators/gemmini/software/gemmini-rocc-tests/build/bareMetalC
mkdir -p ~/nvfp4-logs
echo "== sanity: stock mvin_mvout_acc_full"
timeout 300 spike --extension=gemmini $B/mvin_mvout_acc_full-baremetal; echo "EXIT=$?"
echo "== nvfp4_v0"
timeout 600 spike --extension=gemmini $B/${1:-nvfp4_v0}-baremetal; echo "EXIT=$?"
