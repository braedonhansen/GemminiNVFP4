source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
W=~/nvfp4-logs/bsrc/libgemmini
for D in "" "-DGEMMINI_DIM=32" "-DGEMMINI_DIM=8"; do
  (cd $W && g++ -E -P $D -std=c++17 -I $RISCV/include gemmini.cc 2>/dev/null > /tmp/pp_base.txt)
  (cd $LG && g++ -E -P $D -std=c++17 -I $RISCV/include gemmini.cc 2>/dev/null > /tmp/pp_new.txt)
  echo "variant '$D': lines base=$(wc -l < /tmp/pp_base.txt) new=$(wc -l < /tmp/pp_new.txt) diff_lines=$(diff /tmp/pp_base.txt /tmp/pp_new.txt | wc -l) cmp=$(cmp /tmp/pp_base.txt /tmp/pp_new.txt && echo IDENTICAL)"
done
(cd $LG && g++ -E -P -DGEMMINI_NVFP4 -std=c++17 -I $RISCV/include gemmini.cc 2>/dev/null > /tmp/pp_nv.txt); echo "nvfp4 variant adds $(diff /tmp/pp_base.txt /tmp/pp_nv.txt | grep -c '^>') lines"
grep -c "nvfp4" /tmp/pp_new.txt
