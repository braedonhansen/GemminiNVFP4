package nvfp4pe

import chisel3._
import chisel3.util._
import hardfloat.{AddRawFN, RawFloat, RoundRawFNToRecFN, fNFromRecFN, rawFloatFromRecFN, recFNFromFN}

/** Stage 1 of the pipelined FP32 adder (combinational): IEEE FP32 in -> recode -> raw operands -> AddRawFN (align, add,
  * close/far select). Output is the unrounded raw sum (RawFloat(8, 26)) plus the invalid flag. RNE only. */
class Fp32AddS1 extends Module {
  val io = IO(new Bundle {
    val acc = Input(UInt(32.W))
    val blk = Input(UInt(32.W))
    val raw = Output(new RawFloat(8, 26))
    val invalid = Output(Bool())
  })
  val add = Module(new AddRawFN(8, 24))
  add.io.subOp := false.B
  add.io.a := rawFloatFromRecFN(8, 24, recFNFromFN(8, 24, io.acc))
  add.io.b := rawFloatFromRecFN(8, 24, recFNFromFN(8, 24, io.blk))
  add.io.roundingMode := 0.U // round_near_even
  io.raw := add.io.rawOut
  io.invalid := add.io.invalidExc
}

/** Stage 2 (combinational): round the raw sum to FP32 (RNE) and convert back to IEEE bits. NaN out is canonical 0x7FC00000. */
class Fp32AddS2 extends Module {
  val io = IO(new Bundle {
    val raw = Input(new RawFloat(8, 26))
    val invalid = Input(Bool())
    val sum = Output(UInt(32.W))
  })
  val rnd = Module(new RoundRawFNToRecFN(8, 24, 0))
  rnd.io.invalidExc := io.invalid
  rnd.io.infiniteExc := false.B
  rnd.io.in := io.raw
  rnd.io.roundingMode := 0.U
  rnd.io.detectTininess := true.B
  io.sum := fNFromRecFN(8, 24, rnd.io.out)
}

/** FP32 accumulate adder pipelined into 2 stages (M6.3 Phase B decision). Bit-identical to the 1-cycle `Fp32AccAdd`.
  * Latency 2: operands presented in cycle c give `sum` in cycle c+2. Free running (no valid/stall).
  *   stage 1 (cycle c)  : recode + AddRawFN  -> register R1 (raw sum, 26-bit significand + flags)
  *   stage 2 (cycle c+1): RoundRawFNToRecFN + un-recode -> register R2 = `sum` */
class Fp32AccAdd2 extends Module {
  val io = IO(new Bundle {
    val acc = Input(UInt(32.W))
    val blk = Input(UInt(32.W))
    val sum = Output(UInt(32.W))
  })
  val s1 = Module(new Fp32AddS1)
  val s2 = Module(new Fp32AddS2)
  s1.io.acc := io.acc
  s1.io.blk := io.blk
  s2.io.raw := RegNext(s1.io.raw)
  s2.io.invalid := RegNext(s1.io.invalid)
  io.sum := RegNext(s2.io.sum)
}
