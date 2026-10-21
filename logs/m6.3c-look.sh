cd ~/chipyard-mx/generators/gemmini && git status --short | head; git log --oneline | head -4
wc -l src/main/scala/gemmini/{AccumulatorMem,Scratchpad,LoopMatmul,ExecuteController,MxRequantizer,DMA,ScaleFactorMem}.scala 2>&1
ls src/main/scala/gemmini | head -80
cd software/gemmini-rocc-tests; git status --short | head; ls; ls bareMetalC | grep -i -E "fp4|nvfp4"; ls build* 2>/dev/null| head
