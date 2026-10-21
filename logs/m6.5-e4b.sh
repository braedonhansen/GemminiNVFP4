# M6.5 E4(b): layout control in the RTL: the j-group (N-tile) stride of the FP32 spad store. Mutate in the branch, rebuild, run shape 1, restore with git checkout, rebuild, re-run.
R=/mnt/c/Users/braed/gemmini-nvfp4; G=~/chipyard-mx/generators/gemmini; F=src/main/scala/gemmini/LoopMatmul.scala
RT=$G/software/gemmini-rocc-tests; N=nvfp4_mt_m64n64k128
rm -f ~/nvfp4-logs/m6.5-e4b.done
run() { # tag
  source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh; cd sims/verilator
  make CONFIG=NvFp4GemminiRocketConfig run-binary LOADMEM=1 TIMEOUT_CYCLES=200000000 BINARY=$RT/build_mx_rocket/bareMetalC/$N-baremetal > ~/nvfp4-logs/m6.5-e4b-$1.log 2>&1
  echo "run $1 rc=$?"; grep -E "mismatches of|Assertion" ~/nvfp4-logs/m6.5-e4b-$1.log | head -3; grep -m4 MISMATCH ~/nvfp4-logs/m6.5-e4b-$1.log
}
cd $G
echo "before: $(grep -c 'j \* (4 \* fp32x).U' $F) occurrence(s) of the j-term"
sed -i 's/j \* (4 \* fp32x).U/j * (2 * fp32x).U/' $F
echo "after: mutated j-term count = $(grep -c 'j \* (2 \* fp32x).U' $F) (applied if 1); git diff lines: $(git diff -- $F | grep -c '^[+-][^+-]')"
bash $R/logs/m6.3b-build.sh NvFp4GemminiRocketConfig m65negj | head -1
run neg
cd $G; echo "--- restore with git checkout and rebuild"
git checkout -- $F
echo "restored: mutated count = $(grep -c 'j \* (2 \* fp32x).U' $F), original count = $(grep -c 'j \* (4 \* fp32x).U' $F); git status:"; git status --short | grep -v software/; echo "(clean)"
bash $R/logs/m6.3b-build.sh NvFp4GemminiRocketConfig m65restore | head -1
run restored
touch ~/nvfp4-logs/m6.5-e4b.done
