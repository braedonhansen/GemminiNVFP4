source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh >/dev/null 2>&1
L=~/chipyard-mx/generators/gemmini/software/libgemmini
cd $L && grep -n "nvfp4_unit" Makefile | head -4
make nvfp4_unit > ~/nvfp4-logs/coord-m64-unitbuild.log 2>&1; echo "build rc=$?"
U=$(find $L -name nvfp4_unit -type f | head -1); echo "bin: $U"
grep -n -E "argv|gz|vectors" $L/nvfp4_unit.cc | head -5
