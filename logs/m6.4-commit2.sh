source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $LG; rm -f nvfp4_unit; git status --short
git add gemmini.cc
git -c user.name=Braedonhansen -c user.email=braedon.hansen@gmail.com commit -q -m "NVFP4 model: drop the extension-name macro (gemmini_t::name() is 'gemmini' in every variant, so the lookup in gemmini_custom needs no change)"
git log --oneline | head -3; git diff 8766310 --stat
