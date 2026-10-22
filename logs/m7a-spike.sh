# usage: m7a-spike.sh <stock|mx> <ext> <name> [extlib]  -- runs ~/nvfp4-logs/m7a/bin/<name> in Spike, log to ~/nvfp4-logs/m7a/<name>.spike.log
TREE=$1; EXT=$2; NAME=$3; LIB=$4
source ~/miniforge3/etc/profile.d/conda.sh
case $TREE in stock) cd ~/chipyard;; mx) cd ~/chipyard-mx;; esac
source env.sh
OPT=""; [ -n "$LIB" ] && OPT="--extlib=$LIB"
S=$(date +%s)
echo "CMD: spike $OPT --extension=$EXT ~/nvfp4-logs/m7a/bin/$NAME"
timeout 3000 spike $OPT --extension=$EXT ~/nvfp4-logs/m7a/bin/$NAME > ~/nvfp4-logs/m7a/$NAME.spike.log 2>&1; rc=$?
echo "rc=$rc secs=$(( $(date +%s) - S ))"
grep -E "mismatches|MISMATCH|case [0-9]+ " ~/nvfp4-logs/m7a/$NAME.spike.log | head -40
