# usage: m6.2-test.sh <tag> [mutation command run inside the scratch copy dir]  (scratch copy; repo untouched)
source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.1-env.sh
W=$HOME/nvfp4-logs/m6.2-work
TAG=${1:-main}
mkdir -p $W
rm -f $W/t_$TAG.done
rm -rf $W/proj_$TAG; mkdir -p $W/proj_$TAG
cp -r /mnt/c/Users/braed/gemmini-nvfp4/hw/nvfp4pe/{build.sbt,project,src} $W/proj_$TAG/
mkdir -p $W/proj_$TAG/refmodel/vectors && cp /mnt/c/Users/braed/gemmini-nvfp4/refmodel/vectors/* $W/proj_$TAG/refmodel/vectors/
cd $W/proj_$TAG
[ -n "$2" ] && bash -c "$2"
S=$(date +%s)
sbt -batch "testOnly nvfp4pe.NvFp4MeshSpec" > $W/t_$TAG.log 2>&1; echo "rc=$? secs=$(( $(date +%s)-S ))" > $W/t_$TAG.done
