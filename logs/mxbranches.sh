cd ~/chipyard/generators/gemmini
git fetch -q origin gemmini-mx gemmini-mx-cleanup gemmini-mx-gating 2>&1 | tail -2
for b in gemmini-mx gemmini-mx-cleanup gemmini-mx-gating; do
  echo "=== $b"; git log -1 --format="%h %ad %an" --date=short origin/$b
  echo "ahead of our base: $(git rev-list --count 8c3f9923..origin/$b)  behind: $(git rev-list --count origin/$b..8c3f9923)"
  git log --format="%ad %an: %s" --date=short 8c3f9923..origin/$b | head -8
done
echo "=== cleanup diffstat vs base"; git diff --stat 8c3f9923 origin/gemmini-mx-cleanup | tail -25
echo "=== submodules on cleanup"; git show origin/gemmini-mx-cleanup:.gitmodules 2>/dev/null
cd ~/chipyard; git fetch -q origin gemmini-fp8-exploration-2 2>&1|tail -1; git log -3 --format="%h %ad %an: %s" --date=short origin/gemmini-fp8-exploration-2
