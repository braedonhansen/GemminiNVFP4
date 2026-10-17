package nvfp4pe

import chisel3._
import chisel3.util._

/** Decoded E2M1 magnitude (low 3 bits of the code), per the D1 table.
  * Doubled value = (m3 ? 3 : 1) << k, or 0 when `z`.
  */
class Fp4Dec extends Bundle {
  val m3 = Bool()
  val k  = UInt(2.W)
  val z  = Bool()
}

object NvFp4 {
  val ColW = 13 // signed column partial-sum width: |sum| <= 16*144 = 2304 < 2^12

  /** code[2:0] = (e[1:0], m). e=0: m'=1,k=0 (zero if m=0); e>=1,m=0: m'=1,k=e; e>=1,m=1: m'=3,k=e-1. */
  def decode(x: UInt): Fp4Dec = {
    val e = x(2, 1)
    val m = x(0)
    val d = Wire(new Fp4Dec)
    d.z  := x(2, 0) === 0.U
    d.m3 := e.orR && m
    d.k  := Mux(e === 0.U, 0.U, Mux(m, e - 1.U, e))
    d
  }

  /** |product| of two decoded operands: mux{1,3,9} << (ka+kb). Max 9<<4 = 144, so 8 bits. */
  def magProd(a: Fp4Dec, w: Fp4Dec): UInt = {
    val base = MuxLookup(Cat(a.m3, w.m3), 9.U(4.W))(Seq(0.U -> 1.U(4.W), 1.U -> 3.U(4.W), 2.U -> 3.U(4.W)))
    val sh   = (base << (a.k +& w.k))(7, 0)
    Mux(a.z || w.z, 0.U(8.W), sh)
  }

  /** c + (s ? ~mag : mag) + s as ONE adder with carry-in s: ({c,1} + {x,s}) >> 1.
    * -0 needs no special case: mag=0, s=1 gives c + (-1) + 1 = c.
    */
  def addFold(c: UInt, mag: UInt, s: Bool): UInt = {
    val m13 = Cat(0.U((ColW - 8).W), mag)
    val x   = Mux(s, ~m13, m13)
    val sum = Cat(c, 1.U(1.W)) + Cat(x, s)
    sum(ColW, 1)
  }
}

/** One lane: 4-bit E2M1 x 4-bit E2M1 -> 9-bit signed product of the DOUBLED values (-144..144).
  * Purely combinational (RawModule: no clock/reset ports); flat port names a, w, p.
  */
class NvFp4Mul extends RawModule {
  val a = IO(Input(UInt(4.W)))
  val w = IO(Input(UInt(4.W)))
  val p = IO(Output(SInt(9.W)))

  val mag = NvFp4.magProd(NvFp4.decode(a(2, 0)), NvFp4.decode(w(2, 0)))
  val s   = a(3) ^ w(3)
  val m9  = Cat(0.U(1.W), mag)
  val x   = Mux(s, ~m9, m9)
  p := (x + s)(8, 0).asSInt
}

/** 2x2 outer-product PE: d_ij = c_ij + P(a_i, w_j). Each operand is decoded once and shared (variant V6).
  * Combinational; flat port names match the hand-written Verilog (a0,a1,w0,w1,c00..c11,d00..d11).
  */
class NvFp4PE extends RawModule {
  val a0  = IO(Input(UInt(4.W)))
  val a1  = IO(Input(UInt(4.W)))
  val w0  = IO(Input(UInt(4.W)))
  val w1  = IO(Input(UInt(4.W)))
  val c00 = IO(Input(SInt(NvFp4.ColW.W)))
  val c01 = IO(Input(SInt(NvFp4.ColW.W)))
  val c10 = IO(Input(SInt(NvFp4.ColW.W)))
  val c11 = IO(Input(SInt(NvFp4.ColW.W)))
  val d00 = IO(Output(SInt(NvFp4.ColW.W)))
  val d01 = IO(Output(SInt(NvFp4.ColW.W)))
  val d10 = IO(Output(SInt(NvFp4.ColW.W)))
  val d11 = IO(Output(SInt(NvFp4.ColW.W)))

  val da0 = NvFp4.decode(a0(2, 0))
  val da1 = NvFp4.decode(a1(2, 0))
  val dw0 = NvFp4.decode(w0(2, 0))
  val dw1 = NvFp4.decode(w1(2, 0))

  private def lane(c: SInt, da: Fp4Dec, dw: Fp4Dec, sa: Bool, sw: Bool): SInt =
    NvFp4.addFold(c.asUInt, NvFp4.magProd(da, dw), sa ^ sw).asSInt

  d00 := lane(c00, da0, dw0, a0(3), w0(3))
  d01 := lane(c01, da0, dw1, a0(3), w1(3))
  d10 := lane(c10, da1, dw0, a1(3), w0(3))
  d11 := lane(c11, da1, dw1, a1(3), w1(3))
}

/** Emit SystemVerilog:  sbt "runMain nvfp4pe.Elaborate <outdir>" */
object Elaborate extends App {
  val dir = if (args.nonEmpty) args(0) else "build"
  val opts = Array("-disable-all-randomization", "-strip-debug-info", "--lowering-options=disallowLocalVariables,noAlwaysComb")
  _root_.circt.stage.ChiselStage.emitSystemVerilogFile(new NvFp4PE, Array("--target-dir", dir), opts)
  _root_.circt.stage.ChiselStage.emitSystemVerilogFile(new NvFp4Mul, Array("--target-dir", dir), opts)
}
