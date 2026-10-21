source /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.4-env.sh
find $RISCV/include -name "extension.h" | head; grep -n "get_extension" -A12 $RISCV/include/riscv/processor.h | head -40
grep -rn "REGISTER_EXTENSION" -A8 $RISCV/include/riscv/extension.h
grep -rn "dlopen\|lib%s\|\.so" ~/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests/Makefile* 2>/dev/null | head -3
ls ~/chipyard-mx/toolchains/riscv-tools/riscv-isa-sim/riscv/ 2>/dev/null | head -3
