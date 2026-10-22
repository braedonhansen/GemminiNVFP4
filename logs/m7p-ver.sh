cd ~/chipyard; git rev-parse --short=8 HEAD; git -C generators/gemmini rev-parse --short=8 HEAD; git status --short | head -5; git -C generators/gemmini status --short | head -5
git -C generators/gemmini/software/gemmini-rocc-tests rev-parse --short=8 HEAD 2>/dev/null
