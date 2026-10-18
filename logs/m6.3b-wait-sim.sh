for i in $(seq 1 55); do pgrep -x simulator-chipy >/dev/null || break; sleep 10; done
pgrep -x simulator-chipy >/dev/null && echo "still running" || echo "sim finished"
grep -i -E "assert|FAILED|PASSED|timeout" ~/nvfp4-logs/m6.3b-smoke.log | head -5 | cut -c1-250
tail -c 300 ~/nvfp4-logs/m6.3b-smoke.log
