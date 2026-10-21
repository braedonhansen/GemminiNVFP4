W=~/nvfp4-logs/bsrc/libgemmini; LG=~/chipyard-mx/generators/gemmini/software/libgemmini
cd /tmp; for n in a b; do :; done
objcopy -O binary -j .text $W/libbase_rebuilt.so /tmp/ta.bin; objcopy -O binary -j .text $LG/libgemmini.so /tmp/tb.bin
echo "text bytes differing (rebuilt-HEAD vs new default): $(cmp -l /tmp/ta.bin /tmp/tb.bin | wc -l) of $(stat -c %s /tmp/ta.bin)"
objcopy -O binary -j .text ~/nvfp4-logs/libgemmini.base.so /tmp/tc.bin
echo "text bytes differing (installed-old vs rebuilt-HEAD): $(cmp -l /tmp/tc.bin /tmp/ta.bin | wc -l)"
for f in $W/libbase_rebuilt.so $LG/libgemmini.so; do readelf -S $f | grep -E "\.(text|rodata|data|eh_frame) " | awk '{print $2,$4,$6}' | tr '\n' ';'; echo; done
strings -a $W/libbase_rebuilt.so | sort > /tmp/sa.txt; strings -a $LG/libgemmini.so | sort > /tmp/sb.txt; diff /tmp/sa.txt /tmp/sb.txt | head
