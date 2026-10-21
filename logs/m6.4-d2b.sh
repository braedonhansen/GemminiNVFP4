source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $LG; W=~/nvfp4-logs/bsrc; B=$W/libgemmini; rm -rf $W; mkdir -p $B; ln -s $RT $W/gemmini-rocc-tests; git archive HEAD | tar -x -C $B
# same relative layout for ../gemmini-rocc-tests include
cd $B && g++ -L $RISCV/lib -Wl,-rpath,$RISCV/lib -shared -o libbase_rebuilt.so -std=c++17 -I $RISCV/include -fPIC -O3 gemmini.cc gemmini_perf.cc $(ls perf/*.cc perf/*/*.cc 2>/dev/null) ; echo rc=$?
md5sum libbase_rebuilt.so
for f in $B/libbase_rebuilt.so $LG/libgemmini.so ~/nvfp4-logs/libgemmini.base.so; do objcopy -O binary -j .text $f /tmp/t.$(basename $f).bin; echo "$f text: $(md5sum < /tmp/t.$(basename $f).bin) $(stat -c %s /tmp/t.$(basename $f).bin)"; done
