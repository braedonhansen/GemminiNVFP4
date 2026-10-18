p='/home/braed/chipyard-mx/generators/gemmini/src/main/scala/gemmini/AccumulatorMem.scala'
s=open(p).read()
def rep(old,new,cnt=1):
    global s
    assert s.count(old)==cnt, (old, s.count(old))
    s=s.replace(old,new)

rep("""  acc_sub_banks: Int, use_shared_ext_mem: Boolean, use_mx_scaling: Boolean, meshRows: Int, tileRows: Int
) extends Bundle {""","""  acc_sub_banks: Int, use_shared_ext_mem: Boolean, use_mx_scaling: Boolean, meshRows: Int, tileRows: Int,
  use_nvfp4: Boolean = false
) extends Bundle {""")
rep("""Some(Input(Valid(new ScalingFactorReadResp(2*meshRows*tileRows, 2*meshRows*tileRows))))""",
    """Some(Input(Valid(new ScalingFactorReadResp(2*meshRows*tileRows, 2*meshRows*tileRows, if (use_nvfp4) 40 else 36))))""")
rep("""  meshRows: Int,
  tileRows: Int,
)
  (implicit ev: Arithmetic[T]) extends Module {""","""  meshRows: Int,
  tileRows: Int,
  use_nvfp4: Boolean = false,
)
  (implicit ev: Arithmetic[T]) extends Module {""")
rep("""acc_sub_banks, use_shared_ext_mem, use_mx_scaling, meshRows, tileRows))

  def calculateScaleAddr""","""acc_sub_banks, use_shared_ext_mem, use_mx_scaling, meshRows, tileRows, use_nvfp4))

  def calculateScaleAddr""")
rep("""    when(scale_resp.valid && pipelined_writes(0).valid) {
      // Narrow dim/4 window""","""    if (!use_nvfp4) when(scale_resp.valid && pipelined_writes(0).valid) {
      // Narrow dim/4 window""")

rep("""  val rdata_for_adder = Wire(t)
  rdata_for_adder := DontCare
""","""  // ---- NVFP4 (use_nvfp4): exact E4M3 block-scale stage + 2-stage IEEE FP32 accumulate + RAW-hazard stall ----
  // The whole read-modify-write datapath is NvFp4RmwPipe (ported from hw/nvfp4pe, verified standalone there: see its header for the
  // cycle-by-cycle timeline). It replaces applyE9M0Scale and the shared AccPipe adder. A write fired in cycle t:
  //   t+1 scale bytes arrive (ScaleFactorMem raw E4M3), t+3 SRAM read of the old row, t+4 scale stage output meets the SRAM data,
  //   t+6 the new row (sum, or the scaled block for acc=false) is written; pipelined_writes(acc_latency-1) is that write, so
  //   acc_latency must be 1 + 3 + 2 = 6. RAW hazards are handled by STALL through io.write.ready (no forwarding is possible).
  val nvpipe = if (use_nvfp4) Some(Module(new NvFp4RmwPipe(t.length, 4, io.write.bits.addr.getWidth, t.getWidth / (8 * 32)))) else None
  nvpipe.foreach { p =>
    require(use_mx_scaling && t.length == 16 && meshRows * tileRows == 16, "NVFP4 accumulator: DIM 16 with MX scaling plumbing")
    require(t.head.length == 1 && t.head.head.getWidth == 128, "NVFP4 accumulator entry is 4 x FP32 = 128 bits")
    require(acc_latency == p.L, s"NVFP4 accumulate pipe needs acc_latency = ${p.L}, got $acc_latency")
    p.io.fire := io.write.fire
    p.io.addr := io.write.bits.addr
    p.io.acc := io.write.bits.acc
    p.io.meta := VecInit(io.write.bits.mask.grouped(32).map(_.reduce(_ || _)).toSeq).asUInt
    p.io.rd_data := DontCare
    val sresp = io.scale_rd_resp.get.bits.combined_scales
    for (e <- 0 until t.length) {
      // pre-scale payload: 4 lanes x int16 (sign-extended int13) in the low 64 bits of the 128-bit entry
      p.io.data(e) := io.write.bits.data(e).asUInt(63, 0)
      for (j <- 0 until 4) {
        p.io.sa(e)(j) := sresp(e)(7, 0)
        p.io.sb(e)(j) := sresp(e)(8 * (j + 1) + 7, 8 * (j + 1))
      }
    }
  }

  val rdata_for_adder = Wire(t)
  rdata_for_adder := DontCare
""")
rep("""  io.adder.op1 := rdata_for_adder
  if(use_mx_scaling){
    io.adder.op2 := scaled_data""","""  io.adder.op1 := rdata_for_adder
  if (use_nvfp4) {
    io.adder.op2 := DontCare
    io.adder.valid := false.B
  } else if(use_mx_scaling){
    io.adder.op2 := scaled_data""")
rep("""    val wr_data = Mux(oldest_pipelined_write.bits.acc, adder_sum, oldest_pipelined_write.bits.data)""",
    """    val wr_data = if (use_nvfp4) nvpipe.get.io.wr_data.asUInt.asTypeOf(t)
                  else Mux(oldest_pipelined_write.bits.acc, adder_sum, oldest_pipelined_write.bits.data)""")
rep("""      mem.io.mask := VecInit(oldest_pipelined_write.bits.mask.grouped(32).map(_.reduce(_ || _)).toSeq)""",
    """      mem.io.mask := (if (use_nvfp4) VecInit(nvpipe.get.io.wr_meta.asBools)
                      else VecInit(oldest_pipelined_write.bits.mask.grouped(32).map(_.reduce(_ || _)).toSeq))""")
rep("""      mem.io.raddr_full := (if (widen) foldW(io.write.bits.addr, Mux(io.mx_multi_elem, rd_par, rd_chunk)) else io.write.bits.addr)
      mem.io.ren_full := io.write.fire && io.write.bits.acc""","""      mem.io.raddr_full := (if (use_nvfp4) nvpipe.get.io.rd_addr
                            else if (widen) foldW(io.write.bits.addr, Mux(io.mx_multi_elem, rd_par, rd_chunk)) else io.write.bits.addr)
      mem.io.ren_full := (if (use_nvfp4) nvpipe.get.io.rd_en else io.write.fire && io.write.bits.acc)
      nvpipe.foreach(_.io.rd_data := mem.io.rdata_full.asTypeOf(nvpipe.get.io.rd_data))""")
rep("""  io.write.ready := !block_write_req &&
    !pipelined_writes.map(r => r.valid && r.bits.addr === io.write.bits.addr && io.write.bits.acc).reduce(_||_)""",
    """  // NVFP4: the RAW stall lives in NvFp4RmwPipe (window sized to its 3-cycle-late SRAM read); MX: any in-flight write to the address.
  io.write.ready := !block_write_req && (if (use_nvfp4) nvpipe.get.io.ready else
    !pipelined_writes.map(r => r.valid && r.bits.addr === io.write.bits.addr && io.write.bits.acc).reduce(_||_))""")
open(p,'w').write(s)
print("ok")
