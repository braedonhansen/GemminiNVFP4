source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
L=~/nvfp4-logs; rm -f $L/m5-s5.done
cd generators/gemmini/software/gemmini-rocc-tests
git diff include/gemmini_params.h > $L/m5-params.diff
./build_spike.sh > $L/m5-s5a.log 2>&1; echo spike=$? > $L/m5-s5.rc
./build_mx_rocket.sh bareMetalC > $L/m5-s5b.log 2>&1; echo rocket=$? >> $L/m5-s5.rc
echo done > $L/m5-s5.done
