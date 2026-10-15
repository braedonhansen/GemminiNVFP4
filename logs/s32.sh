cd ~/chipyard
grep -rn "WithSerialTLBundleParams\|STANDARD_TLBUNDLE_PARAMS" generators/testchipip/src 2>/dev/null | head -3
grep -rn "outerLatencyCycles" generators/rocket-chip-inclusive-cache/design 2>/dev/null | head -3
cd generators/gemmini
git grep -n -E "import (freechips|testchipip|org\.chipsalliance|radiance)" origin/gemmini-mx-cleanup -- src/main chipyard | sed 's/.*:[0-9]*://' | sort | uniq -c | sort -rn | head -30
echo --- diff of imports vs base
git diff 8c3f9923 origin/gemmini-mx-cleanup -- src/main chipyard | grep -E "^\+.*import (freechips|testchipip|radiance|chipyard)" | sort -u | head -20
git log --oneline 8c3f9923..origin/master | head -5
git diff --stat 8c3f9923 origin/master | tail -3
