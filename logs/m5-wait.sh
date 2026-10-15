# usage: m5-wait.sh markerfile
while [ ! -f "$1" ]; do sleep 90; done; cat "$1"
