package nvfp4pe

import chisel3._
import chisel3.util._
import hardfloat.{MulRawFN, RawFloat, RoundRawFNToRecFN, fNFromRecFN, rawFloatFromRecFN, recFNFromFN}

/** Stage 1 of the mvout tensor-scale multiplier (combinational): IEEE FP32 x IEEE FP32 -> recode -> raw operands ->
  * MulRawFN (24x24 significand product folded to a 26-bit sticky form). Output is the unrounded raw product plus the
  * invalid flag. RNE only. M6.3 Phase C (C1). */
class Fp32MulS1 extends Module {
  val io = IO(new Bundle {
    val a = Input(UInt(32.W))
    val b = Input(UInt(32.W))
    val raw = Output(new RawFloat(8, 26))
    val invalid = Output(Bool())
  })
  val mul = Module(new MulRawFN(8, 24))
  mul.io.a := rawFloatFromRecFN(8, 24, recFNFromFN(8, 24, io.a))
  mul.io.b := rawFloatFromRecFN(8, 24, recFNFromFN(8, 24, io.b))
  io.raw := mul.io.rawOut
  io.invalid := mul.io.invalidExc
}

/** Stage 2 (combinational): round the raw product to FP32 (RNE, tininess detected after rounding) and convert back to
  * IEEE bits. NaN out is canonical 0x7FC00000. Together with `Fp32MulS1` this is hardfloat's MulRecFN split at the raw
  * boundary, with the recode/un-recode around it. */
class Fp32MulS2 extends Module {
  val io = IO(new Bundle {
    val raw = Input(new RawFloat(8, 26))
    val invalid = Input(Bool())
    val out = Output(UInt(32.W))
  })
  val rnd = Module(new RoundRawFNToRecFN(8, 24, 0))
  rnd.io.invalidExc := io.invalid
  rnd.io.infiniteExc := false.B
  rnd.io.in := io.raw
  rnd.io.roundingMode := 0.U // round_near_even
  rnd.io.detectTininess := true.B
  io.out := fNFromRecFN(8, 24, rnd.io.out)
}

/** FP32 x FP32 -> FP32 (RNE) multiplier pipelined into 2 stages; used at mvout to apply the tensor scale
  * (`out = acc * ((tA*tB)*0.25f)`, acc_scale path). Latency 2: operands in cycle c give `out` in cycle c+2. Free running. */
class Fp32Mul2 extends Module {
  val io = IO(new Bundle {
    val a = Input(UInt(32.W))
    val b = Input(UInt(32.W))
    val out = Output(UInt(32.W))
  })
  val s1 = Module(new Fp32MulS1)
  val s2 = Module(new Fp32MulS2)
  s1.io.a := io.a
  s1.io.b := io.b
  s2.io.raw := RegNext(s1.io.raw)
  s2.io.invalid := RegNext(s1.io.invalid)
  io.out := RegNext(s2.io.out)
}
