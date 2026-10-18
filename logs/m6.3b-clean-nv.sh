# clean the NVFP4 build products (created by this task) so B4 can be timed end to end (elaboration + Verilator)
cd ~/chipyard-mx/sims/verilator
rm -rf generated-src/chipyard.harness.TestHarness.NvFp4GemminiRocketConfig simulator-chipyard.harness-NvFp4GemminiRocketConfig
ls generated-src
