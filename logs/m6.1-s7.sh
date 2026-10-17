# usage: m6.1-s7.sh <tag>   (copies the repo project to a scratch dir, runs sbt test, writes log + .done)
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.1-env.sh
W=$HOME/nvfp4-logs/m6.1-work
TAG=${1:-main}
rm -f $W/s7_$TAG.done
rm -rf $W/proj_$TAG; mkdir -p $W/proj_$TAG
cp -r /mnt/c/Users/braed/gemmini-nvfp4/hw/nvfp4pe/{build.sbt,project,src} $W/proj_$TAG/
[ -n "$2" ] && bash -c "$2"   # optional mutation applied to the scratch copy
cd $W/proj_$TAG
# tests find the golden via ../../refmodel relative to cwd; provide it in scratch
mkdir -p $W/proj_$TAG/refmodel/vectors && cp /mnt/c/Users/braed/gemmini-nvfp4/refmodel/vectors/e2m1_pairs.json $W/proj_$TAG/refmodel/vectors/
S=$(date +%s)
sbt -batch test > $W/s7_$TAG.log 2>&1; echo "rc=$? secs=$(( $(date +%s)-S ))" > $W/s7_$TAG.done
