# Rebuild libgemmini from the pristine MX base commit (87663107, no NVFP4 branch changes) outside the tree and rerun the MX Spike checks with it.
unset GIT_DIR GIT_WORK_TREE
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
LG=~/chipyard-mx/generators/gemmini/software/libgemmini; B=~/nvfp4-logs/m7a/mxbase; W=$B/libgemmini
rm -rf $B; mkdir -p $W; ln -s ~/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests $B/gemmini-rocc-tests   # gemmini.cc includes ../gemmini-rocc-tests/include/vpu_ref.h
git -C $LG archive 87663107 | tar -x -C $W
cp $LG/gemmini_params.h $W/gemmini_params.h     # generated header of the installed config (DIM 16), not tracked at that commit
ls $W | head -20
cd $W
echo "build: g++ -DGEMMINI_DIM=16? (see Makefile) -shared ..."
cat Makefile | grep -n "g++" | head -3
EXTRA_SRC=$(ls gemmini_perf.cc perf/*.cc perf/*/*.cc 2>/dev/null | tr '\n' ' ')
g++ -L $RISCV/lib -Wl,-rpath,$RISCV/lib -shared -o libgemmini_mxbase.so -std=c++17 -I $RISCV/include -fPIC -O3 gemmini.cc $EXTRA_SRC 2>&1 | grep -E "error" | head
ls -la libgemmini_mxbase.so
for n in m7a_mx_fp8 m7a_mx_fp4; do
  timeout 3000 spike --extlib=$W/libgemmini_mxbase.so --extension=gemmini ~/nvfp4-logs/m7a/bin/$n > ~/nvfp4-logs/m7a/$n.mxbase.spike.log 2>&1; echo "$n rc=$?"
  grep -E "^m7a_mx" ~/nvfp4-logs/m7a/$n.mxbase.spike.log
done
