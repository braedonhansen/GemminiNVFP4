cd ~/nvfp4-logs; W=m6.3a-work
for f in $W/s7_c0main.log $W/s7_c0neg.log $W/s7_c1neg.log; do echo "== $f"; grep -E "RESULT|Tests:" $f | cut -c1-260; done
echo "== e2e runs"; for f in m6.3c-r1.log m6.3c-neg.log m6.3c-rtl0neg.log m6.3c-r3.log; do echo "-- $f"; grep -E "MISMATCH|nvfp4_e2e M=" $f; done
echo "== C4"; cat m6.3c-c4.out | cut -c1-200 | grep -v "^	"
echo "== MX normalised hash"; cat m6.3c-mxbase/mx-before.norm.sha | sha256sum; cat m6.3c-mxbase/mx-after.norm.sha | sha256sum
