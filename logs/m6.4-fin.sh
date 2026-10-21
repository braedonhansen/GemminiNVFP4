source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $LG; git format-patch -2 --stdout 8766310..HEAD > $R/logs/m6.4-libgemmini.patch; wc -l $R/logs/m6.4-libgemmini.patch; git log --format='%h %s' 8766310..HEAD | cut -c1-80
git status --short; git -C $RT status --short
