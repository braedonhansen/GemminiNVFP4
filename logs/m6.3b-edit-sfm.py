p='/home/braed/chipyard-mx/generators/gemmini/src/main/scala/gemmini/ScaleFactorMem.scala'
s=open(p).read()
def rep(old,new,cnt=1):
    global s
    assert s.count(old)==cnt, (old, s.count(old))
    s=s.replace(old,new)
rep("""class ScalingFactorReadResp(numRows: Int, numCols: Int) extends Bundle {
  val combined_scales = Vec(numRows/2, UInt(36.W))
}""","""// scaleBits: bits per response element. MX: 4 lanes x 9-bit summed E8M0 scale = 36. NVFP4: raw E4M3 bytes, sA (8) + 4 x sB (32) = 40.
class ScalingFactorReadResp(numRows: Int, numCols: Int, scaleBits: Int = 36) extends Bundle {
  val combined_scales = Vec(numRows/2, UInt(scaleBits.W))
}""")
rep("""class ScalingFactorMemIO(addrWidth: Int, dataWidth: Int, numRows: Int, numCols: Int, meshRows:Int, tileRows: Int) extends Bundle {""",
"""class ScalingFactorMemIO(addrWidth: Int, dataWidth: Int, numRows: Int, numCols: Int, meshRows:Int, tileRows: Int, scaleBits: Int = 36) extends Bundle {""")
rep("val read_resp = Decoupled(new ScalingFactorReadResp(numRows, numCols))","val read_resp = Decoupled(new ScalingFactorReadResp(numRows, numCols, scaleBits))")
rep("""  meshRows: Int,
  tileRows: Int,
) extends Module {
  val scaleMemSizeFactor = 4""","""  meshRows: Int,
  tileRows: Int,
  scaleSize: Int = 32,       // block size in elements (MX: 32, NVFP4: 16); sets how many k-tiles share one scale row
  nvfp4: Boolean = false,    // respond with raw E4M3 bytes (sA, sB per lane) instead of summed E8M0 exponents
) extends Module {
  val scaleMemSizeFactor = 4""")
rep("""    meshRows,
    tileRows,
  ))

  val initByte""","""    meshRows,
    tileRows,
    if (nvfp4) 40 else 36,
  ))

  val initByte""")
rep("""  // MX block = 32 elements. tilesPerMxBlock k-tiles share one block scale -> advance the scale-row
  // address once every tilesPerMxBlock k-tiles. DIM16: 32/16=2 -> shift 1; DIM32: 32/32=1 -> shift 0.
  val tilesPerMxBlock = 32 / (meshRows*tileRows)""","""  // MX block = scaleSize elements (32 for MX, 16 for NVFP4). tilesPerMxBlock k-tiles share one block scale -> advance the
  // scale-row address once every tilesPerMxBlock k-tiles. MX DIM16: 32/16=2 -> shift 1; DIM32 (MX) and DIM16 (NVFP4,
  // scaleSize 16): 1 -> shift 0.
  val tilesPerMxBlock = scaleSize / (meshRows*tileRows)""")
rep("""  for(i <- 0 until 2*meshRows*tileRows) {
    for(j <- 0 until 2*meshRows*tileRows) {
      when(read_fire_d1) {""","""  if (!nvfp4) for(i <- 0 until 2*meshRows*tileRows) {
    for(j <- 0 until 2*meshRows*tileRows) {
      when(read_fire_d1) {""")
rep("""  when(read_fire_d1) {
    io.read_resp.valid := combined_scales_valid
    when(fp8Mode){""","""  if (nvfp4) {
    // NVFP4: no sA+sB pre-multiply here (Q3): the response carries the raw E4M3 bytes and the scale stage inside AccumulatorMem
    // multiplies them. One write = 2 output rows x 32 output columns in 16 entries x 4 lanes (ExecuteController packed layout):
    // entry e<8 -> act row 2c, entry e>=8 -> act row 2c+1 (c = scale_counter 0..15 = write index within the 32x32 pass);
    // lane j of entry e -> weight column 4*(e%8)+j. The 32 act and 32 weight bytes are latched on the pass's first write.
    val act_reg = RegInit(VecInit(Seq.fill(2*numScaleRows)(0.U(8.W))))
    val w_reg = RegInit(VecInit(Seq.fill(2*numScaleRows)(0.U(8.W))))
    when(read_fire_real_d) {
      act_reg := act_scales
      w_reg := weight_scales
    }
    val first_write = scale_counter_d1 === 0.U
    val act_sel = Mux(first_write, act_scales, act_reg)
    val w_sel = Mux(first_write, weight_scales, w_reg)
    when(read_fire_d1) {
      io.read_resp.valid := true.B
      for (e <- 0 until numScaleRows) {
        val hi = e >= numScaleRows / 2
        val sa = act_sel(Cat(scale_counter_d1, hi.B))
        val sb = (0 until 4).map(j => w_sel(4 * (e % (numScaleRows / 2)) + j))
        io.read_resp.bits.combined_scales(e) := Cat((sb.reverse :+ sa))
      }
    }
  } else when(read_fire_d1) {
    io.read_resp.valid := combined_scales_valid
    when(fp8Mode){""")
open(p,'w').write(s)
print("ok")
