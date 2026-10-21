# Make nvfp4_unit fail when it checked nothing (missing/empty vector files), then prove both directions.
L=~/chipyard-mx/generators/gemmini/software/libgemmini; F=$L/nvfp4_unit.cc
cd $L; git checkout -q nvfp4
sed -n 47,48p $F | grep -c -E 'nvfp4_unit: %s|return total_bad != 0' | grep -q 2 || { echo "lines 47-48 are not the expected ones"; exit 1; }
sed -i '47,48d' $F
sed -i '46r /dev/stdin' $F <<'C'
  // An empty or missing vector file must not pass: require that every check actually ran.
  bool ran = n > 0 && blocks > 0;
  if (!ran) printf("nvfp4_unit: checked nothing (scale vectors %ld, acc blocks %ld)\n", n, blocks);
  bool ok = ran && total_bad == 0;
  printf("nvfp4_unit: %s\n", ok ? "PASS" : "FAIL");
  return ok ? 0 : 1;
C
sed -n 44,54p $F
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh >/dev/null 2>&1; cd $L
make nvfp4_unit > ~/nvfp4-logs/coord-m64-unitfix.log 2>&1 || { echo BUILD FAILED; tail ~/nvfp4-logs/coord-m64-unitfix.log; exit 1; }
V=/mnt/c/Users/braed/gemmini-nvfp4/refmodel/vectors
./nvfp4_unit $V/scale_stage.txt.gz $V/acc_seq.txt.gz | tail -1; echo "real vectors rc=${PIPESTATUS[0]}"
./nvfp4_unit /nonexistent1.gz /nonexistent2.gz 2>/dev/null | tail -2; echo "missing files rc=${PIPESTATUS[0]}"
git -c user.name=Braedonhansen -c user.email=braedon.hansen@gmail.com commit -q -am "nvfp4_unit: fail when no vectors were checked (missing or empty input files)" && git log --oneline -1
