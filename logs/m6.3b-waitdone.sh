F="/mnt/c/Users/braed/AppData/Local/Temp/claude/C--Users-braed-Portfolio/050609e9-5c84-47d8-99f9-2801adaceb6e/tasks/bmpmdz69s.output"
for i in $(seq 1 55); do grep -q "=== done" "$F" && break; sleep 10; done
tail -12 "$F" | cut -c1-200
