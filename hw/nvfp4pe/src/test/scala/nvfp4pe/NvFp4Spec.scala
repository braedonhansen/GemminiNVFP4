package nvfp4pe

import chisel3._
import chisel3.simulator.EphemeralSimulator._
import org.scalatest.funsuite.AnyFunSuite

import java.nio.file.{Files, Paths}

/** Exhaustive ChiselSim (Verilator) tests against refmodel/vectors/e2m1_pairs.json (doubled E2M1 values). */
class NvFp4Spec extends AnyFunSuite {

  /** (a, b) -> signed product, parsed from the golden JSON. */
  private lazy val golden: Map[(Int, Int), Int] = {
    val rel = "refmodel/vectors/e2m1_pairs.json"
    val p = Seq("../../" + rel, rel, "../" + rel).map(Paths.get(_)).find(Files.exists(_))
      .getOrElse(fail(s"cannot find $rel from ${Paths.get("").toAbsolutePath}"))
    val txt = new String(Files.readAllBytes(p), "UTF-8")
    val re = """"a":\s*(\d+),\s*"b":\s*(\d+),\s*"product":\s*(-?\d+)""".r
    val m = re.findAllMatchIn(txt).map(g => (g.group(1).toInt, g.group(2).toInt) -> g.group(3).toInt).toMap
    assert(m.size == 256, s"expected 256 golden pairs, got ${m.size}")
    m
  }

  private def wrap13(x: Int): Int = ((x + 4096) & 0x1fff) - 4096 // to signed 13-bit

  test("NvFp4Mul: all 256 (a,w) pairs match the golden JSON") {
    var mism = 0
    simulate(new NvFp4Mul) { dut =>
      for (a <- 0 until 16; w <- 0 until 16) {
        dut.a.poke(a.U); dut.w.poke(w.U)
        val got = dut.p.peek().litValue.toInt
        if (got != golden((a, w))) { mism += 1; if (mism < 10) println(s"MISMATCH a=$a w=$w got=$got exp=${golden((a, w))}") }
      }
    }
    println(s"RESULT NvFp4Mul checked=256 mismatches=$mism")
    assert(mism == 0)
  }

  test("NvFp4PE: all 65536 (a0,a1,w0,w1) at c=0, plus 13-bit bound spot checks") {
    var mism = 0
    var n = 0
    def check(dut: NvFp4PE, a0: Int, a1: Int, w0: Int, w1: Int, c: Seq[Int]): Unit = {
      dut.a0.poke(a0.U); dut.a1.poke(a1.U); dut.w0.poke(w0.U); dut.w1.poke(w1.U)
      dut.c00.poke(c(0).S); dut.c01.poke(c(1).S); dut.c10.poke(c(2).S); dut.c11.poke(c(3).S)
      val got = Seq(dut.d00, dut.d01, dut.d10, dut.d11).map(_.peek().litValue.toInt)
      val exp = Seq(
        wrap13(c(0) + golden((a0, w0))), wrap13(c(1) + golden((a0, w1))),
        wrap13(c(2) + golden((a1, w0))), wrap13(c(3) + golden((a1, w1))))
      n += 1
      if (got != exp) { mism += 1; if (mism < 10) println(s"MISMATCH a=$a0,$a1 w=$w0,$w1 c=$c got=$got exp=$exp") }
    }
    simulate(new NvFp4PE) { dut =>
      for (a0 <- 0 until 16; a1 <- 0 until 16; w0 <- 0 until 16; w1 <- 0 until 16)
        check(dut, a0, a1, w0, w1, Seq(0, 0, 0, 0))
      // bounds: c = +max-144 and -max+144 (max = 4095 / -4096), mixed lanes; all 16 corner codes (+-0, +-6)
      val hi = 4095 - 144; val lo = -4096 + 144
      val codes = Seq(0, 7, 8, 15, 1, 9, 5, 13)
      for (a0 <- codes; a1 <- codes; w0 <- codes; w1 <- codes) {
        check(dut, a0, a1, w0, w1, Seq(hi, hi, hi, hi))
        check(dut, a0, a1, w0, w1, Seq(lo, lo, lo, lo))
        check(dut, a0, a1, w0, w1, Seq(hi, lo, lo, hi))
      }
      // the extremes themselves (wrap check at the 13-bit edge is only exercised by values reachable in-range)
      check(dut, 7, 7, 7, 7, Seq(hi, hi, hi, hi))   // +144 lands exactly on 4095
      check(dut, 15, 15, 7, 7, Seq(lo, lo, lo, lo)) // -144 lands exactly on -4096
    }
    println(s"RESULT NvFp4PE checked=$n mismatches=$mism")
    assert(mism == 0)
  }
}
