W=$HOME/nvfp4-logs/m6.2-work; D=/mnt/c/Users/braed/gemmini-nvfp4/logs/m6.2-synth
for t in NvFp4Mesh_d4_l0 NvFp4Mesh_d16_l0; do cp $W/synth/${t}_aig.stat $W/synth/${t}_cmos.stat $W/synth/${t}_ltp.txt $D/; done
for v in a85 a45; do for k in aig cmos; do cp $W/mxpe/synth_$v/MxFpMul_$k.stat $D/MxFpMul_${v}_$k.stat; done; cp $W/mxpe/synth_$v/MxFpMul_ltp.txt $D/MxFpMul_${v}_ltp.txt; done
cp $W/synth.csv $D/mesh.csv; cp $W/mxpe/synth.csv $D/mxpe.csv
