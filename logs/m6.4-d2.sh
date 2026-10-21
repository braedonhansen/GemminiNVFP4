source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
cd $LG; git config --global --get-all safe.directory | head -2
cp libgemmini.so ~/nvfp4-logs/libgemmini.base.so; cp libgemmini_dim32.so ~/nvfp4-logs/libgemmini_dim32.base.so; cp libgemmini_dim8.so ~/nvfp4-logs/libgemmini_dim8.base.so
git check-ignore -v libgemmini.so; git ls-files | head -20
rm -f libgemmini.so libgemmini_dim32.so libgemmini_dim8.so libgemmini_nvfp4.so
make -j4 default > ~/nvfp4-logs/m6.4-build.log 2>&1; echo make_rc=$?; grep -i "warning\|error" ~/nvfp4-logs/m6.4-build.log | head
md5sum libgemmini*.so ~/nvfp4-logs/*.base.so
nm -D libgemmini_nvfp4.so | grep -c nvfp4; nm -C libgemmini_nvfp4.so | grep -i "register_gemmini"
nm -C libgemmini.so | grep -i "register_gemmini"
