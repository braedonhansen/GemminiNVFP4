source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh
R=/mnt/c/Users/braed/gemmini-nvfp4
D=~/chipyard/generators/gemmini/software/gemmini-rocc-tests
RUN=${1:-spike}
for v in isum out; do
  cp $R/logs/m4_neg_$v.h $D/bareMetalC/nvfp4_v0_data.h; touch $D/bareMetalC/nvfp4_v0.c
  (cd $D/build && make BAREMETAL_ONLY=1 bareMetalC >/dev/null 2>&1)
  echo "== negative control ($v), $RUN"
  timeout 600 spike --extension=gemmini $D/build/bareMetalC/nvfp4_v0-baremetal; echo "EXIT=$?"
done
# restore
cp $R/hw/tests/nvfp4_v0_data.h $D/bareMetalC/nvfp4_v0_data.h; touch $D/bareMetalC/nvfp4_v0.c
(cd $D/build && make BAREMETAL_ONLY=1 bareMetalC >/dev/null 2>&1)
echo "== restored"
timeout 600 spike --extension=gemmini $D/build/bareMetalC/nvfp4_v0-baremetal; echo "EXIT=$?"
cmp $R/hw/tests/nvfp4_v0_data.h $D/bareMetalC/nvfp4_v0_data.h && echo header-restored
