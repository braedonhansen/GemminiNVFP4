package nvfp4pe

import chisel3._
import chisel3.util._
import hardfloat.{AddRecFN, fNFromRecFN, recFNFromFN}

/** NVFP4 block-scale stage (M6.3 Phase A): FP32 bits of  isum * sA * sB  for 4 lanes, exact, 3 register stages.
  *
  *  stage 0: decode both E4M3 scales: sP = sigA*sigB (4x4 -> <= 8 bits), eS = eA'+eB' (5 bits), sign, NaN flag
  *  stage 1: prod = |isum| * sP  (13 x 8 -> 21 bits)
  *  stage 2: leading-one normalize and pack to FP32, no rounding
  *
  * Why nothing rounds: sigA, sigB <= 15 so sP <= 225 (8 bits); |isum| <= 4096 (13-bit magnitude; 2304 in use),
  * so prod < 2^20 and fits in 21 bits, which is <= 24 (the FP32 significand). The exponent is
  * eS + 127 - lz in [109, 157]: always a normal FP32, so no overflow and no subnormals either.
  *
  * E4M3: e == 0 is subnormal (sig = m, exponent field treated as 1); 0x7F/0xFF are NaN -> the lane outputs the canonical
  * qNaN 0x7FC00000 (same as refmodel/scale_stage.py). The sign bit of each scale is honoured (sign = sI ^ sA ^ sB,
  * also for a zero result), although NVFP4 scales are positive.
  *
  * Latency: out_valid / out appear 3 cycles after in_valid / lanes (registers after each of the 3 stages).
  */
class NvFp4ScaleStage(lanes: Int = 4) extends Module {
  val io = IO(new Bundle {
    val in_valid = Input(Bool())
    val isum = Input(Vec(lanes, SInt(13.W)))
    val sa = Input(Vec(lanes, UInt(8.W)))
    val sb = Input(Vec(lanes, UInt(8.W)))
    val out_valid = Output(Bool())
    val out = Output(Vec(lanes, UInt(32.W)))
  })

  private def dec(c: UInt): (UInt, UInt) = { // (significand incl. hidden bit, effective exponent field)
    val e = c(6, 3); val m = c(2, 0)
    val sub = e === 0.U
    (Cat(!sub, m), Mux(sub, 1.U(4.W), e))
  }

  // ---- stage 0 ----
  val v0 = RegNext(io.in_valid, false.B)
  val s0P = Wire(Vec(lanes, UInt(8.W))); val s0E = Wire(Vec(lanes, UInt(5.W)))
  val s0S = Wire(Vec(lanes, Bool())); val s0N = Wire(Vec(lanes, Bool()))
  for (i <- 0 until lanes) {
    val (siga, ea) = dec(io.sa(i)); val (sigb, eb) = dec(io.sb(i))
    s0P(i) := siga * sigb
    s0E(i) := ea +& eb
    s0S(i) := io.sa(i)(7) ^ io.sb(i)(7)
    s0N(i) := io.sa(i)(6, 0).andR || io.sb(i)(6, 0).andR
  }
  val r0P = RegNext(s0P); val r0E = RegNext(s0E); val r0S = RegNext(s0S); val r0N = RegNext(s0N)
  val r0I = RegNext(io.isum)

  // ---- stage 1 ----
  val v1 = RegNext(v0, false.B)
  val s1Prod = Wire(Vec(lanes, UInt(21.W))); val s1S = Wire(Vec(lanes, Bool()))
  for (i <- 0 until lanes) {
    val neg = r0I(i) < 0.S
    val mag = Mux(neg, (-r0I(i)).asUInt, r0I(i).asUInt)(12, 0) // |-4096| = 4096 fits in 13 bits unsigned
    s1Prod(i) := mag * r0P(i)
    s1S(i) := r0S(i) ^ neg
  }
  val r1Prod = RegNext(s1Prod); val r1E = RegNext(r0E); val r1S = RegNext(s1S); val r1N = RegNext(r0N)

  // ---- stage 2 ----
  val v2 = RegNext(v1, false.B)
  val s2 = Wire(Vec(lanes, UInt(32.W)))
  for (i <- 0 until lanes) {
    val prod = r1Prod(i)
    val lz = PriorityEncoder(Reverse(prod))               // 0..20 (don't care when prod == 0)
    val norm = (prod << lz)(20, 0)                         // leading one at bit 20
    val frac = Cat(norm(19, 0), 0.U(3.W))                  // 23 bits, exact
    val expo = (r1E(i) +& 127.U(8.W)) - lz                 // biased exponent, 109..157
    val zero = prod === 0.U
    s2(i) := Mux(r1N(i), "h7fc00000".U(32.W),
      Mux(zero, Cat(r1S(i), 0.U(31.W)), Cat(r1S(i), expo(7, 0), frac)))
  }
  io.out := RegNext(s2)
  io.out_valid := v2
}

/** FP32 add on recoded (hardfloat) operands: the rounding core only. RNE, no subtraction. */
class Fp32AccAddRec extends Module {
  val io = IO(new Bundle {
    val acc = Input(UInt(33.W))
    val blk = Input(UInt(33.W))
    val sum = Output(UInt(33.W))
  })
  val add = Module(new AddRecFN(8, 24))
  add.io.subOp := false.B
  add.io.a := io.acc
  add.io.b := io.blk
  add.io.roundingMode := 0.U // round_near_even
  add.io.detectTininess := true.B
  io.sum := add.io.out
}

/** FP32 add on standard IEEE bit patterns (recode in, add, un-recode out); combinational. NaN out is canonical 0x7FC00000. */
class Fp32AccAdd extends Module {
  val io = IO(new Bundle {
    val acc = Input(UInt(32.W))
    val blk = Input(UInt(32.W))
    val sum = Output(UInt(32.W))
  })
  val core = Module(new Fp32AccAddRec)
  core.io.acc := recFNFromFN(8, 24, io.acc)
  core.io.blk := recFNFromFN(8, 24, io.blk)
  io.sum := fNFromRecFN(8, 24, core.io.sum)
}

/** Scale stage + per-lane FP32 accumulator register (one add per K block). `first` starts a new accumulation (acc operand = +0).
  * Latency: a block poked at cycle t is in `acc` at cycle t+4 (3 scale stages + 1 add). `acc_valid` pulses with it. */
class NvFp4ScaleAcc(lanes: Int = 4) extends Module {
  val io = IO(new Bundle {
    val in_valid = Input(Bool())
    val first = Input(Bool())
    val isum = Input(Vec(lanes, SInt(13.W)))
    val sa = Input(Vec(lanes, UInt(8.W)))
    val sb = Input(Vec(lanes, UInt(8.W)))
    val acc_valid = Output(Bool())
    val acc = Output(Vec(lanes, UInt(32.W)))
  })
  val st = Module(new NvFp4ScaleStage(lanes))
  st.io.in_valid := io.in_valid; st.io.isum := io.isum; st.io.sa := io.sa; st.io.sb := io.sb
  val f1 = RegNext(io.first); val f2 = RegNext(f1); val f3 = RegNext(f2)
  val accR = RegInit(VecInit(Seq.fill(lanes)(0.U(32.W))))
  val adders = Seq.fill(lanes)(Module(new Fp32AccAdd))
  for (i <- 0 until lanes) {
    adders(i).io.acc := Mux(f3, 0.U, accR(i))
    adders(i).io.blk := st.io.out(i)
    when(st.io.out_valid) { accR(i) := adders(i).io.sum }
  }
  io.acc := accR
  io.acc_valid := RegNext(st.io.out_valid, false.B)
}

object ElaborateScale extends App {
  val dir = if (args.nonEmpty) args(0) else "build"
  val opts = Array("-disable-all-randomization", "-strip-debug-info", "--lowering-options=disallowLocalVariables,noAlwaysComb")
  def emit(m: => RawModule) = _root_.circt.stage.ChiselStage.emitSystemVerilogFile(m, Array("--target-dir", dir), opts)
  emit(new NvFp4ScaleStage)
  emit(new Fp32AccAdd)
  emit(new Fp32AccAddRec)
  emit(new NvFp4ScaleAcc)
}
