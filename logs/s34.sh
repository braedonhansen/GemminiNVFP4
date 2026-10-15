cd ~/chipyard/generators/gemmini
B=origin/gemmini-mx-cleanup
git merge-base $B origin/master
for c in 8c3f9923 8f515786 28180b24; do echo "== $c"; git diff --stat $c^1 $c | tail -25; done
