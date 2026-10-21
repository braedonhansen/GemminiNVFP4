for i in $(seq 1 100); do [ -f ~/nvfp4-logs/m6.3c-rtl0.done ] && break; sleep 5; done
tail -4 ~/nvfp4-logs/m6.3c-rtl0.out | cut -c1-200
cd ~/chipyard-mx/generators/gemmini; git status --short | grep -v rocc-tests; git log --oneline -1
