source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
echo RISCV=$RISCV; which spike; ls -la $RISCV/lib | grep -i gemmini
cd $LG; git checkout -b nvfp4 2>&1; git log --oneline | head -2
md5sum libgemmini*.so $RISCV/lib/libgemmini*.so
cd $RT; git status --short | head; ls build_spike/bareMetalC 2>/dev/null | head -3; cat build_spike.sh; git -C $RT log --oneline | head -1
