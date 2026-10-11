cd ~/chipyard/generators/gemmini/software/gemmini-rocc-tests
grep -n "template" bareMetalC/Makefile | cat -A | head; ls bareMetalC | head -3; ls build/bareMetalC | grep -v baremetal | head; ls build
git check-ignore -v bareMetalC/Makefile; git ls-files bareMetalC | grep -i make
