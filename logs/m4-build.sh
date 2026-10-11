source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh
R=/mnt/c/Users/braed/gemmini-nvfp4
D=~/chipyard/generators/gemmini/software/gemmini-rocc-tests
cd $D
cp $R/hw/tests/nvfp4_v0.c $D/bareMetalC/nvfp4_v0.c
cp $R/hw/tests/nvfp4_v0_data.h $D/bareMetalC/nvfp4_v0_data.h
python3 - <<'PY'
p="bareMetalC/Makefile"
s=open(p).read()
if "nvfp4_v0" not in s:
    s=s.replace("\ttemplate \\n","\ttemplate \\n\tnvfp4_v0 \\n",1)
    open(p,"w").write(s)
PY
git status --short; git diff
cd build/bareMetalC && make nvfp4_v0-baremetal 2>&1 | tail -20
ls -la nvfp4_v0-baremetal
