package nvfp4pe

import chisel3._
import chisel3.simulator.EphemeralSimulator._
import org.scalatest.funsuite.AnyFunSuite

/** M6.3 Phase C step C1: the mvout tensor-scale multiplier (FP32 x FP32 -> FP32, RNE, hardfloat MulRawFN + RoundRawFNToRecFN)
  * against the JVM's IEEE float multiply. */
class Fp32MulSpec extends AnyFunSuite {
  private def canon(f: Float): Long = if (f.isNaN) 0x7fc00000L else java.lang.Float.floatToRawIntBits(f).toLong & 0xffffffffL

  test("Fp32Mul2: 2-cycle latency, bit-exact vs JVM float multiply (random, subnormal, zero, inf, NaN; streaming)") {
    val rng = new scala.util.Random(777)
    val N = 400000
    val as = new Array[Int](N); val bs = new Array[Int](N)
    def rnd32 = rng.nextInt()
    def withExp(e: Int) = (rng.nextInt() & 0x807fffff) | ((e & 0xff) << 23)
    for (i <- 0 until N) {
      val kind = rng.nextInt(8)
      val (a, b) = kind match {
        case 0 => (rnd32, rnd32)                                              // fully random
        case 1 => (withExp(rng.nextInt(60)), withExp(rng.nextInt(60)))        // tiny: subnormal / underflow products
        case 2 => (withExp(1 + rng.nextInt(254)), withExp(60 + rng.nextInt(128))) // wide
        case 3 => (withExp(127 + rng.nextInt(60)), withExp(127 + rng.nextInt(60)))// near overflow
        case 4 => (withExp(rng.nextInt(2) * rng.nextInt(3)), rnd32)           // subnormal / zero x random
        case 5 => (withExp(100 + rng.nextInt(55)), withExp(100 + rng.nextInt(55))) // moderate (typical acc x scale)
        case 6 => (withExp(64 + rng.nextInt(10)), withExp(190 + rng.nextInt(10))) // product exponent near 1 (exact-ish)
        case _ => (rnd32 & 0xff800000 | (rnd32 & 0x7ffff), withExp(rng.nextInt(256))) // few mantissa bits (round-tie cases)
      }
      as(i) = a; bs(i) = b
    }
    val sp = Seq(0, 0x80000000, 0x7f800000, 0xff800000, 0x7fc00000, 0x7f800001, 0xffc00000, 0x00000001, 0x80000001, 0x007fffff, 0x00800000,
      0x7f7fffff, 0xff7fffff, 0x3f800000, 0xbf800000, 0x3e800000, 0x40000000, 0x3f000000, 0x33800000)
    var mism = 0; var n = 0
    simulate(new Fp32Mul2) { dut =>
      val total = N + sp.length * sp.length
      def inA(i: Int) = if (i < N) as(i) else sp((i - N) / sp.length)
      def inB(i: Int) = if (i < N) bs(i) else sp((i - N) % sp.length)
      for (t <- 0 until total + 3) {
        if (t >= 2 && t - 2 < total) {
          val i = t - 2
          val exp = canon(java.lang.Float.intBitsToFloat(inA(i)) * java.lang.Float.intBitsToFloat(inB(i)))
          val got = dut.io.out.peek().litValue.toLong
          n += 1
          if (got != exp) { mism += 1; if (mism < 10) println(f"MISMATCH a=${inA(i)}%08x b=${inB(i)}%08x got=$got%08x exp=$exp%08x") }
        }
        if (t < total) { dut.io.a.poke((inA(t).toLong & 0xffffffffL).U); dut.io.b.poke((inB(t).toLong & 0xffffffffL).U) }
        dut.clock.step()
      }
    }
    println(s"RESULT Fp32Mul2 latency=2 checked=$n mismatches_vs_JVM=$mism")
    assert(mism == 0 && n >= 200000)
  }
}
