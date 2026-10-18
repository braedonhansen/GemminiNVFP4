package nvfp4pe

import chisel3._
import chisel3.util._

/** Read-modify-write datapath + hazard control for the NVFP4 accumulator (M6.3 Phase B). This is the exact logic that is
  * ported into Gemmini's AccumulatorMem (NVFP4 branch). The accumulator SRAM itself is outside this module.
  *
  * Timeline of one write that fires (`fire`) in cycle t (ScaleLat = 3, AddLat = 2):
  *   t      : fire; req fields + int13 lanes are registered into pw(0). The scale-factor memory is read in cycle t.
  *   t+1    : pw(0) valid; scale bytes (sa per entry, sb per lane) arrive; scale-stage stage 0 starts
  *   t+3    : pw(ScaleLat-1) valid; SRAM read of the OLD accumulator row is issued (rd_en/rd_addr) if acc
  *   t+4    : scale-stage output (exact FP32 block value) and SRAM read data meet at the adder inputs
  *   t+6    : adder output (2 stages); pw(L-1), L = 1+ScaleLat+AddLat = 6, is valid; the row (sum, or the block value for a
  *            non-acc write) is written to the SRAM (wr_*).
  *
  * Read-after-write hazard, resolved by STALL (not forwarding): an accumulate to address A whose SRAM read (cycle
  * t2+ScaleLat) happens before an earlier write to A is in the SRAM (visible from cycle t1+L+1) would read stale data.
  * That is t2-t1 < L+1-ScaleLat = AddLat+2 = 4, i.e. the earlier write is in pw(0..L-ScaleLat-1). While that is true,
  * `ready` is low and the producer must hold the request. (Forwarding cannot work: the earlier sum does not exist until
  * t1+6 but the later add needs it at t1+d+3 with d >= 1, a loop-carried dependency of latency 6, so back-to-back
  * same-address accumulates have to serialize.) Non-acc writes never read, and write order = fire order (fixed
  * latency FIFO), so they need no stall.
  *
  * `data` carries int13 lanes sign-extended to 16 bits (lane j in bits 16j+15:16j of each entry).
  */
class NvFp4RmwPipe(val entries: Int, val lanes: Int = 4, val addrW: Int = 8, val metaW: Int = 1) extends Module {
  val ScaleLat = 3
  val AddLat = 2
  val L = 1 + ScaleLat + AddLat
  val io = IO(new Bundle {
    // request side (cycle t)
    val fire = Input(Bool())
    val addr = Input(UInt(addrW.W))
    val acc = Input(Bool())
    val meta = Input(UInt(metaW.W))
    val data = Input(Vec(entries, UInt((lanes * 16).W)))
    val ready = Output(Bool())
    // scale bytes, valid in cycle t+1 (same cycle pw(0) is valid); sa per lane (Gemmini broadcasts one sa per entry)
    val sa = Input(Vec(entries, Vec(lanes, UInt(8.W))))
    val sb = Input(Vec(entries, Vec(lanes, UInt(8.W))))
    // SRAM read port (1-cycle read latency) and write port
    val rd_en = Output(Bool())
    val rd_addr = Output(UInt(addrW.W))
    val rd_data = Input(Vec(entries, UInt((lanes * 32).W)))
    val wr_valid = Output(Bool())
    val wr_addr = Output(UInt(addrW.W))
    val wr_meta = Output(UInt(metaW.W))
    val wr_acc = Output(Bool())
    val wr_data = Output(Vec(entries, UInt((lanes * 32).W)))
    // in-flight write addresses (pw(0..L-1)) for other hazard checks (mvout reads)
    val inflight = Output(Vec(L, Valid(UInt(addrW.W))))
  })

  class Pw extends Bundle { val addr = UInt(addrW.W); val acc = Bool(); val meta = UInt(metaW.W) }
  val pwV = RegInit(VecInit(Seq.fill(L)(false.B)))
  val pw = Reg(Vec(L, new Pw))
  pwV(0) := io.fire
  pw(0).addr := io.addr; pw(0).acc := io.acc; pw(0).meta := io.meta
  for (i <- 1 until L) { pwV(i) := pwV(i - 1); pw(i) := pw(i - 1) }
  for (i <- 0 until L) { io.inflight(i).valid := pwV(i); io.inflight(i).bits := pw(i).addr }

  // ---- RAW hazard: stall an accumulate that would read before an earlier write to the same address lands ----
  val hazard = io.acc && (0 until (L - ScaleLat)).map(i => pwV(i) && pw(i).addr === io.addr).reduce(_ || _)
  io.ready := !hazard

  // ---- SRAM read of the old row, ScaleLat cycles after fire ----
  io.rd_en := pwV(ScaleLat - 1) && pw(ScaleLat - 1).acc
  io.rd_addr := pw(ScaleLat - 1).addr

  // ---- datapath ----
  val d0 = RegNext(io.data)
  val blkOut = Wire(Vec(entries, Vec(lanes, UInt(32.W))))
  val sumOut = Wire(Vec(entries, Vec(lanes, UInt(32.W))))
  for (e <- 0 until entries) {
    val st = Module(new NvFp4ScaleStage(lanes))
    st.io.in_valid := pwV(0)
    for (j <- 0 until lanes) {
      st.io.isum(j) := d0(e)(16 * j + 12, 16 * j).asSInt
      st.io.sa(j) := io.sa(e)(j)
      st.io.sb(j) := io.sb(e)(j)
      val add = Module(new Fp32AccAdd2)
      add.io.acc := io.rd_data(e)(32 * j + 31, 32 * j)
      add.io.blk := st.io.out(j)
      blkOut(e)(j) := ShiftRegister(st.io.out(j), AddLat)
      sumOut(e)(j) := add.io.sum
    }
  }
  val oldest = pw(L - 1)
  io.wr_valid := pwV(L - 1)
  io.wr_addr := oldest.addr
  io.wr_meta := oldest.meta
  io.wr_acc := oldest.acc
  for (e <- 0 until entries)
    io.wr_data(e) := Mux(oldest.acc, sumOut(e).asUInt, blkOut(e).asUInt)
}

/** Standalone test wrapper: NvFp4RmwPipe + a flop-array SRAM (depth rows of entries*lanes*32 bits) with a debug read port. */
class NvFp4AccBank(val entries: Int, val lanes: Int, val depth: Int) extends Module {
  val aw = log2Ceil(depth)
  val pipe = Module(new NvFp4RmwPipe(entries, lanes, aw, 1))
  val io = IO(new Bundle {
    val fire = Input(Bool())
    val addr = Input(UInt(aw.W))
    val acc = Input(Bool())
    val data = Input(Vec(entries, UInt((lanes * 16).W)))
    val ready = Output(Bool())
    val sa = Input(Vec(entries, Vec(lanes, UInt(8.W))))
    val sb = Input(Vec(entries, Vec(lanes, UInt(8.W))))
    val wr_valid = Output(Bool())
    val wr_addr = Output(UInt(aw.W))
    val wr_data = Output(Vec(entries, UInt((lanes * 32).W)))
    val dbg_addr = Input(UInt(aw.W))
    val dbg_data = Output(Vec(entries, UInt((lanes * 32).W)))
  })
  pipe.io.fire := io.fire; pipe.io.addr := io.addr; pipe.io.acc := io.acc; pipe.io.meta := 0.U; pipe.io.data := io.data
  io.ready := pipe.io.ready
  pipe.io.sa := io.sa; pipe.io.sb := io.sb
  val mem = Mem(depth, Vec(entries, UInt((lanes * 32).W)))
  pipe.io.rd_data := RegNext(mem(pipe.io.rd_addr))
  when(pipe.io.wr_valid) { mem(pipe.io.wr_addr) := pipe.io.wr_data }
  io.wr_valid := pipe.io.wr_valid; io.wr_addr := pipe.io.wr_addr; io.wr_data := pipe.io.wr_data
  io.dbg_data := mem(io.dbg_addr)
}

object ElaborateB0 extends App {
  val dir = if (args.nonEmpty) args(0) else "build"
  val opts = Array("-disable-all-randomization", "-strip-debug-info", "--lowering-options=disallowLocalVariables,noAlwaysComb")
  def emit(m: => RawModule) = _root_.circt.stage.ChiselStage.emitSystemVerilogFile(m, Array("--target-dir", dir), opts)
  emit(new Fp32AddS1)
  emit(new Fp32AddS2)
  emit(new Fp32AccAdd2)
  emit(new NvFp4AccBank(2, 4, 8))
}
