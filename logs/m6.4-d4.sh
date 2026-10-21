source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $LG; make -j4 default > ~/nvfp4-logs/m6.4-build.log 2>&1; echo make_rc=$?
make install > ~/nvfp4-logs/m6.4-install.log 2>&1; echo install_rc=$?; ls -la $RISCV/lib/libgemmini*.so
cd $RT
timeout 600 spike --extension=gemmini_nvfp4 build_spike/bareMetalC/nvfp4_e2e-baremetal > ~/nvfp4-logs/m6.4-d4-run.log 2>&1; echo spike_rc=$?
tail -8 ~/nvfp4-logs/m6.4-d4-run.log
