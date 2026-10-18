cd ~/chipyard-mx/generators/gemmini
git add src/main/scala/gemmini/{NvFp4PE,NvFp4Mesh,NvFp4ScaleStage,Fp32AccAdd2,NvFp4RmwPipe,NvFp4MeshAdapter,Mesh,MeshWithDelays,ExecuteController,GemminiConfigs,ScaleFactorMem,AccumulatorMem,Scratchpad,LoopMatmul,Controller,ConfigsFP}.scala chipyard/GemminiConfigs.scala
git status --short
git -c user.name="Braedonhansen" -c user.email="braedon.hansen@gmail.com" commit -q -F - <<'MSG'
NVFP4-only config (M6.3 Phase B): NvFp4Mesh, E4M3 scale stage, pipelined FP32 accumulate

- NvFp4GemminiRocketConfig (use_nvfp4): integer NvFp4Mesh behind a Mesh-shaped adapter (MeshWithDelays), accType = 4 x IEEE FP32
- AccumulatorMem: NvFp4RmwPipe (3-stage exact scale stage + 2-stage FP32 add, RAW stall), acc_latency 6
- ScaleFactorMem: raw E4M3 bytes (sA + 4 x sB per entry); scaleSize replaces the hardcoded 32 (ScaleFactorMem, LoopMatmul)
- MX configs unchanged (all changes gated by use_nvfp4 / defaults)

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git log --oneline -3
