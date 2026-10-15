# usage: m5-launch.sh script.sh  -> runs detached
setsid nohup bash "$1" > "$1.out" 2>&1 < /dev/null &
sleep 3; echo launched
