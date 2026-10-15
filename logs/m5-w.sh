# usage: m5-w.sh marker [maxminutes]
for i in $(seq 1 ${2:-9}); do [ -f "$1" ] && break; sleep 60; done
if [ -f "$1" ]; then echo "DONE: $(cat $1)"; else echo "still running"; fi
