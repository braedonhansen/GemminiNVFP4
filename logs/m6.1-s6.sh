source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.1-env.sh
W=$HOME/nvfp4-logs/m6.1-work
rm -rf $W/proj; mkdir -p $W/proj
cp -r /mnt/c/Users/braed/gemmini-nvfp4/hw/nvfp4pe/{build.sbt,project,src} $W/proj/
cd $W/proj
rm -rf $W/chisel_sv
sbt -batch "runMain nvfp4pe.Elaborate $W/chisel_sv" > $W/s6.log 2>&1; echo "sbt rc=$?"
tail -15 $W/s6.log; ls -la $W/chisel_sv
