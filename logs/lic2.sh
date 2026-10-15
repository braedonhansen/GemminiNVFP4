cd ~/chipyard
for r in . generators/gemmini generators/gemmini/software/gemmini-rocc-tests; do
  echo "== $r"
  git -C "$r" log -1 --format="last LICENSE change: %h %ad %s" --date=short origin/HEAD -- LICENSE
  git -C "$r" log -1 --format="upstream head: %h %ad" --date=short origin/HEAD
  git -C "$r" log -1 --format="local head: %h %ad" --date=short HEAD
done
