bash /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.3a-s7.sh full "" "test"
cat ~/nvfp4-logs/m6.3a-work/s7_full.done
grep -E "RESULT|Tests:|passed|FAILED|\- " ~/nvfp4-logs/m6.3a-work/s7_full.log | cut -c1-220 | head -40
