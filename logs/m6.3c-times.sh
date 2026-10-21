cd ~/nvfp4-logs
for t in c2nv c2mx c2b c4mx rtl0neg rtl0restore; do
  [ -f m6.3b-$t.end ] && echo "$t secs=$(( $(cat m6.3b-$t.end) - $(cat m6.3b-$t.start) )) mem=$(cat m6.3b-$t.mem 2>/dev/null)"
done
