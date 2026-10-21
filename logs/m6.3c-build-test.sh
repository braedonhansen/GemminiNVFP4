# Install nvfp4_e2e (untracked files + one Makefile list line) into the MX tree's rocc-tests and build the rocket binary.
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
R=/mnt/c/Users/braed/gemmini-nvfp4; T=~/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests
cd $T
cp $R/hw/tests/nvfp4_e2e.c $R/hw/tests/nvfp4_e2e_data.h bareMetalC/
grep -q nvfp4_e2e bareMetalC/Makefile || sed -i '/^\ttemplate /a\	nvfp4_e2e \' bareMetalC/Makefile
(cd bareMetalC && git diff Makefile)
touch bareMetalC/nvfp4_e2e.c; rm -f build_mx_rocket/bareMetalC/nvfp4_e2e-baremetal
./build_mx_rocket.sh bareMetalC > ~/nvfp4-logs/m6.3c-testbuild.log 2>&1; echo build_rc=$?
ls -la build_mx_rocket/bareMetalC/nvfp4_e2e-baremetal
grep -n "nvfp4_e2e" ~/nvfp4-logs/m6.3c-testbuild.log | head -5 | cut -c1-300
grep -n -i "warning\|error" ~/nvfp4-logs/m6.3c-testbuild.log | grep nvfp4_e2e | head
