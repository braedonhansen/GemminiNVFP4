cd ~/chipyard-mx/sims/verilator
cp -p simulator-chipyard.harness-MxFp4OnlyGemminiRocketConfig ~/nvfp4-logs/m5-mx-sim.orig
md5sum ~/nvfp4-logs/m5-mx-sim.orig
ls generated-src/ ; ls generated-src/chipyard.harness.TestHarness.MxFp4OnlyGemminiRocketConfig | head -3
find generated-src/chipyard.harness.TestHarness.MxFp4OnlyGemminiRocketConfig -name '*.sv' -newer ~/nvfp4-logs/m5-mx-sim.orig | head -3
