unset GIT_DIR GIT_WORK_TREE
for d in $HOME/chipyard $HOME/chipyard/generators/gemmini $HOME/chipyard-mx $HOME/chipyard-mx/generators/gemmini $HOME/chipyard-mx/generators/gemmini/software/libgemmini $HOME/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests $HOME/chipyard-mx/generators/gemmini/mxgen $HOME/chipyard/generators/gemmini/software/gemmini-rocc-tests; do
  echo "$d $(git -C $d rev-parse --short=8 HEAD) $(git -C $d branch --show-current)"
done
