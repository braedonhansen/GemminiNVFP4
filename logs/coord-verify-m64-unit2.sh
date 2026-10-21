V=/mnt/c/Users/braed/gemmini-nvfp4/refmodel/vectors
ls -la $V/scale_stage.txt.gz $V/acc_seq.txt.gz | awk '{print $5, $9}'
~/chipyard-mx/generators/gemmini/software/libgemmini/nvfp4_unit $V/scale_stage.txt.gz $V/acc_seq.txt.gz 2>&1 | tail -4; echo "rc=${PIPESTATUS[0]}"
