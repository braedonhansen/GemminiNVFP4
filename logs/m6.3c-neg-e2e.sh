# C3 negative control: flip one expected output bit (installed copy of the header only), rebuild, rerun: exactly 1 mismatch expected; then restore and rerun.
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard-mx; source env.sh
R=/mnt/c/Users/braed/gemmini-nvfp4; T=~/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests; H=$T/bareMetalC/nvfp4_e2e_data.h
B=$T/build_mx_rocket/bareMetalC/nvfp4_e2e-baremetal
# row 5 is the 6th line-group; flip bit 0 of out_bits[5][7] = element 5*32+7 = 167 => line 20 (8 per line), column 7
LN=$(( $(grep -n 'out_bits\[' $H | cut -d: -f1) + 1 + 167/8 ))
echo "target line $LN: $(sed -n ${LN}p $H | cut -c1-120)"
cp $H $H.orig
python3 - <<PY
import re
p="$H"; ln=$LN; col=167%8
L=open(p).read().split("\n")
toks=re.findall(r"0x[0-9a-f]{8}u", L[ln-1]); t=toks[col]
new="0x%08xu"%(int(t[:-1],16)^1)
L[ln-1]=L[ln-1].replace(t,new,1) if col==0 else L[ln-1]
parts=L[ln-1].split(",") if col else None
if col:
    # replace the col-th token
    seen=-1; out=[]
    for seg in re.split(r"(0x[0-9a-f]{8}u)", L[ln-1]):
        if re.fullmatch(r"0x[0-9a-f]{8}u", seg):
            seen+=1
            if seen==col: seg=new
        out.append(seg)
    L[ln-1]="".join(out)
open(p,"w").write("\n".join(L))
print("flipped",t,"->",new)
PY
echo "mutation applied: $(diff $H.orig $H | grep -c '^>')"
touch $T/bareMetalC/nvfp4_e2e.c; rm -f $B
(cd $T && ./build_mx_rocket.sh bareMetalC > ~/nvfp4-logs/m6.3c-negbuild.log 2>&1; echo build_rc=$?)
bash $R/logs/m6.3c-run.sh neg | grep -v "^if \|^	"
echo "--- restore"
cp $H.orig $H; rm $H.orig
touch $T/bareMetalC/nvfp4_e2e.c; rm -f $B
(cd $T && ./build_mx_rocket.sh bareMetalC > ~/nvfp4-logs/m6.3c-negbuild2.log 2>&1; echo build_rc=$?)
bash $R/logs/m6.3c-run.sh r2 | grep -v "^if \|^	"
cmp $H $R/hw/tests/nvfp4_e2e_data.h && echo "header restored (identical to repo)"
