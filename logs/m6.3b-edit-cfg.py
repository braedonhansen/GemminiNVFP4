base='/home/braed/chipyard-mx/generators/gemmini/'
def edit(fn, pairs):
    s=open(base+fn).read()
    for old,new in pairs:
        assert s.count(old)==1,(fn,old,s.count(old))
        s=s.replace(old,new)
    open(base+fn,'w').write(s)
edit('src/main/scala/gemmini/ConfigsFP.scala',[
("""  lazy val e3m2OnlyMxFPConfig = standaloneMxFPConfig.copy(""","""  // NVFP4-only build (M6.3 option iii). Everything MX-specific stays elaboration-gated; differences from fp4OnlyMxFPConfig:
  //  - use_nvfp4: NvFp4Mesh (exact int13 column sums) replaces the MX float Mesh; AccumulatorMem runs the exact E4M3
  //    block-scale stage + 2-stage IEEE FP32 accumulate (NvFp4RmwPipe) instead of applyE9M0Scale + the BF16 adder.
  //  - accType = 4 x IEEE FP32 per entry (128 bits). acc_capacity doubled so the accumulator keeps the same number of rows.
  //  - spatialArrayOutputType = 64-bit container of 4 x int16 lanes (int13 sums sign-extended), PRE-scale.
  //  - meshProd/AccPrecisionList left empty: they are only consumed by the MX Mesh/Tile (unused by NvFp4Mesh); they feed
  //    neither max_simultaneous_matmuls nor the mesh tags (Q6).
  //  - scaleSize = 16 (one block per mesh pass); acc_latency = 1 + 3 (scale stage) + 2 (FP32 add) = 6.
  //  - has_acc_mvin = false: all accumulator writes are mesh writes (pre-scale int lanes); no bias/mvin into the accumulator.
  //  - tile_latency = 0, mesh_output_delay = 1 inherited from standaloneMxFPConfig.
  lazy val nvfp4MxFPConfig = fp4OnlyMxFPConfig.copy(
    accType = MxFloat(8, 24, 4, pad = false),
    accTypeProjected = MxFloat(8, 24, 4, pad = false),
    spatialArrayOutputType = MxFloat(8, 8, 4, false, false),
    meshProdPrecisionList = Seq(),
    meshAccPrecisionList = Seq(),
    scaleSize = 16,
    acc_latency = 6,
    acc_capacity = CapacityInKilobytes(128),
    has_acc_mvin = false,
    use_nvfp4 = true,
    headerFileName = "gemmini_params_nvfp4.h",   // keep the MX gemmini_params.h (used by the M5 tests) untouched
  )
  lazy val e3m2OnlyMxFPConfig = standaloneMxFPConfig.copy("""),
("""class GemminiMxFPE3M2OnlyStandaloneConfig extends Config((site, here, up) => {""","""// NVFP4-only build: integer NvFp4Mesh + E4M3 block-scale stage + FP32 accumulator (M6.3 option iii).
class GemminiNvFp4StandaloneConfig extends Config((site, here, up) => {
  case BuildRoCC => Seq((p: Parameters) => {
    implicit val q = p; implicit val v = implicitly[ValName]
    LazyModule(new Gemmini(GemminiMxFPConfigs.nvfp4MxFPConfig))
  })
})
class GemminiMxFPE3M2OnlyStandaloneConfig extends Config((site, here, up) => {"""),
])
edit('chipyard/GemminiConfigs.scala',[
("""class MxE3M2OnlyGemminiRocketConfig extends Config(""","""// NVFP4-only build (M6.3): E2M1 act/weight, E4M3 block scales (16 elements), exact int sums, FP32 accumulator.
class NvFp4GemminiRocketConfig extends Config(
  new gemmini.GemminiNvFp4StandaloneConfig ++
  new freechips.rocketchip.rocket.WithNHugeCores(1) ++
  new chipyard.config.WithSystemBusWidth(128) ++
  new chipyard.config.AbstractConfig)

class MxE3M2OnlyGemminiRocketConfig extends Config("""),
])
print("ok")
