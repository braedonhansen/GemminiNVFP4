# usage: m6.3a-s7.sh <tag> [mutation-cmd] [sbt-test-args]   (copy project to scratch, optionally mutate the COPY, run sbt)
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.1-env.sh
W=$HOME/nvfp4-logs/m6.3a-work
TAG=${1:-main}
mkdir -p $W
rm -f $W/s7_$TAG.done
rm -rf $W/proj_$TAG; mkdir -p $W/proj_$TAG
cp -r /mnt/c/Users/braed/gemmini-nvfp4/hw/nvfp4pe/{build.sbt,project,src} $W/proj_$TAG/
cd $W/proj_$TAG
[ -n "$2" ] && bash -c "$2"   # mutation applied to the scratch copy
mkdir -p refmodel/vectors && cp /mnt/c/Users/braed/gemmini-nvfp4/refmodel/vectors/* refmodel/vectors/
S=$(date +%s)
sbt -batch "${3:-test}" > $W/s7_$TAG.log 2>&1; echo "rc=$? secs=$(( $(date +%s)-S ))" > $W/s7_$TAG.done
