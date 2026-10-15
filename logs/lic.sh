cd ~/chipyard
for r in . generators/gemmini generators/gemmini/software/gemmini-rocc-tests; do
  echo "=== $r"; ls $r | grep -i -E "licen|copying" ; head -3 $r/LICENSE* 2>/dev/null
  git -C $r fetch -q origin 2>&1 | tail -1
  git -C $r log --oneline -3 origin/HEAD -- 'LICENSE*' 'COPYING*' 2>/dev/null || git -C $r log --oneline -3 --all -- 'LICENSE*'
  git -C $r diff --stat HEAD origin/HEAD -- 'LICENSE*' 2>/dev/null
done
