# Coordinator re-verification of M7.A. Run from WSL: bash /mnt/c/Users/braed/gemmini-nvfp4/logs/coord-verify-m7a.sh
R=/mnt/c/Users/braed/gemmini-nvfp4
W=~/nvfp4-logs/m7a-coord; mkdir -p $W
cd $R
echo "== regenerate headers and diff"
for t in "int8 m7a_int8" "fp32 m7a_fp32" "mx fp8 m7a_mx_fp8" "mx fp4 m7a_mx_fp4"; do
  set -- $t; name=${@: -1}
  if [ "$1" = mx ]; then cmd.exe /c ".venv\Scripts\python refmodel\export_m7a.py mx $2 $(wslpath -w $W)\${name}_data.h" >/dev/null 2>&1
  else cmd.exe /c ".venv\Scripts\python refmodel\export_m7a.py $1 $(wslpath -w $W)\${name}_data.h" >/dev/null 2>&1; fi
  cmp $W/${name}_data.h hw/tests/${name}_data.h && echo "$name header IDENTICAL ($(wc -c < $W/${name}_data.h) B)" || echo "$name header DIFFERS"
done
echo "== rebuild + Spike"
for t in "stock m7a_int8 gemmini" "fp32 m7a_fp32 gemmini" "mx m7a_mx_fp8 gemmini" "mx m7a_mx_fp4 gemmini" "mx m7a_mx_fp4ctl gemmini" "mx nvfp4_m7a_k1024 gemmini_nvfp4" "mx nvfp4_m7a_outlier gemmini_nvfp4"; do
  set -- $t
  rm -f ~/nvfp4-logs/m7a/bin/$2
  bash $R/logs/m7a-build.sh $1 $2 > $W/$2.build 2>&1
  [ -f ~/nvfp4-logs/m7a/bin/$2 ] || { echo "$2 BUILD FAILED"; tail -5 $W/$2.build; continue; }
  TREE=$1; [ $TREE = fp32 ] && TREE=stock
  LIB=""; [ $1 = fp32 ] && LIB=$HOME/nvfp4-logs/m7a/libgemmini-fp32/libgemmini_fp32.so
  echo "-- $2"; bash $R/logs/m7a-spike.sh $TREE $3 $2 $LIB 2>&1 | tail -8
done
