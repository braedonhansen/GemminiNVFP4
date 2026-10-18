# Coordinator negative control for M6.2: swap the mesh PE weight-buffer select, expect mesh tests to fail.
W=$HOME/nvfp4-logs/m6.1-work
MUT='F=$HOME/nvfp4-logs/m6.1-work/proj_coordneg/src/main/scala/nvfp4pe/NvFp4Mesh.scala; sed -i "s/val w = Mux(prop, c2, c1)/val w = Mux(prop, c1, c2)/" $F; echo MUTATED=$(grep -c "val w = Mux(prop, c1, c2)" $F)'
bash /mnt/c/Users/braed/gemmini-nvfp4/logs/m6.1-s7.sh coordneg "$MUT"
cat $W/s7_coordneg.done; grep -E "Tests:|\*\*\* FAILED" $W/s7_coordneg.log | cut -c1-90
