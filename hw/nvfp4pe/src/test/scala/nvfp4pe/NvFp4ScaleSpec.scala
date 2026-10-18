package nvfp4pe

import chisel3._
import chisel3.simulator.EphemeralSimulator._
import org.scalatest.funsuite.AnyFunSuite

import java.io.{BufferedReader, InputStreamReader}
import java.nio.file.{Files, Path, Paths}
import java.util.zip.GZIPInputStream
import scala.collection.mutable

/** Scale stage + FP32 accumulate vs refmodel/scale_stage.py vectors (refmodel/vectors/{scale_stage,acc_seq}.txt.gz). */
class NvFp4ScaleSpec extends AnyFunSuite {

  private def vecPath(name: String): Path = {
    val rel = s"refmodel/vectors/$name"
    Seq("../../" + rel, rel, "../" + rel).map(Paths.get(_)).find(Files.exists(_))
      .getOrElse(fail(s"cannot find $rel from ${Paths.get("").toAbsolutePath}"))
  }
  private def lines(name: String): Iterator[String] = {
    val r = new BufferedReader(new InputStreamReader(new GZIPInputStream(Files.newInputStream(vecPath(name))), "UTF-8"))
    Iterator.continually(r.readLine()).takeWhile(_ != null)
  }
  private def hex(s: String): Long = java.lang.Long.parseLong(s, 16)

  case class V(isum: Int, sa: Int, sb: Int, exp: Long)

  test("NvFp4ScaleStage: bit-exact vs refmodel (all 65,536 sA x sB pairs x 6 isums + 100k random), streaming every cycle") {
    val vs = lines("scale_stage.txt.gz").map { l => val f = l.split(' '); V(f(0).toInt, f(1).toInt, f(2).toInt, hex(f(3))) }.toArray
    val Lat = 3
    var checked = 0L; var mism = 0L
    simulate(new NvFp4ScaleStage) { dut =>
      // latency / valid check: one isolated block, then bubbles
      dut.io.in_valid.poke(true.B)
      for (l <- 0 until 4) { dut.io.isum(l).poke(2304.S); dut.io.sa(l).poke(0x38.U); dut.io.sb(l).poke(0x38.U) }
      dut.clock.step()
      dut.io.in_valid.poke(false.B)
      for (c <- 1 until 6) {
        dut.io.out_valid.expect((c == Lat).B) // visible after `Lat` total steps
        dut.clock.step()
      }
      // stream: 4 vectors per cycle
      val groups = (vs.length + 3) / 4
      val pend = mutable.Queue[Array[V]]()
      def check(): Unit = {
        val g = pend.dequeue()
        for (l <- g.indices) {
          val got = dut.io.out(l).peek().litValue.toLong
          checked += 1
          if (got != g(l).exp) { mism += 1; if (mism < 10) println(f"MISMATCH isum=${g(l).isum} sa=${g(l).sa}%02x sb=${g(l).sb}%02x got=$got%08x exp=${g(l).exp}%08x") }
        }
      }
      dut.io.in_valid.poke(true.B)
      for (gi <- 0 until groups + Lat) {
        if (gi >= Lat) { dut.io.out_valid.expect(true.B); check() }
        if (gi < groups) {
          val g = vs.slice(gi * 4, gi * 4 + 4)
          for (l <- 0 until 4) { val v = g(math.min(l, g.length - 1)); dut.io.isum(l).poke(v.isum.S); dut.io.sa(l).poke(v.sa.U); dut.io.sb(l).poke(v.sb.U) }
          pend.enqueue(g)
        } else dut.io.in_valid.poke(false.B)
        dut.clock.step()
      }
      assert(pend.isEmpty)
    }
    println(s"RESULT NvFp4ScaleStage latency=3 vectors=$checked mismatches=$mism")
    assert(checked == vs.length && mism == 0)
  }

  test("NvFp4ScaleAcc: FP32 accumulate sequences bit-exact vs refmodel float32 order (>= 10k sequences, every step checked)") {
    // parse sequences
    val seqs = mutable.ArrayBuffer[mutable.ArrayBuffer[V]]()
    for (l <- lines("acc_seq.txt.gz")) {
      if (l == "S") seqs += mutable.ArrayBuffer[V]()
      else { val f = l.split(' '); seqs.last += V(f(0).toInt, f(1).toInt, f(2).toInt, hex(f(3))) }
    }
    assert(seqs.length >= 10000)
    // group 4 sequences of equal length (lanes share valid/first); pad the last group by repeating a sequence
    val groups = seqs.groupBy(_.length).toSeq.sortBy(_._1).flatMap { case (_, ss) =>
      ss.grouped(4).map(g => (0 until 4).map(i => g(math.min(i, g.length - 1))).toArray).toSeq
    }
    val totalSeqs = seqs.length
    val totalSteps = seqs.map(_.length).sum
    var checked = 0L; var mism = 0L
    val Lat = 4
    simulate(new NvFp4ScaleAcc) { dut =>
      // flatten all groups into a block stream (one element = one cycle): (group, idx)
      val stream = groups.flatMap(g => (0 until g(0).length).map(k => (g, k)))
      val pend = mutable.Queue[(Array[mutable.ArrayBuffer[V]], Int)]()
      for (t <- 0 until stream.length + Lat) {
        if (t >= Lat) {
          dut.io.acc_valid.expect(true.B)
          val (g, k) = pend.dequeue()
          for (l <- 0 until 4) {
            val got = dut.io.acc(l).peek().litValue.toLong; val exp = g(l)(k).exp
            checked += 1
            if (got != exp) { mism += 1; if (mism < 10) println(f"MISMATCH lane=$l step=$k isum=${g(l)(k).isum} got=$got%08x exp=$exp%08x") }
          }
        }
        if (t < stream.length) {
          val (g, k) = stream(t)
          dut.io.in_valid.poke(true.B); dut.io.first.poke((k == 0).B)
          for (l <- 0 until 4) { val v = g(l)(k); dut.io.isum(l).poke(v.isum.S); dut.io.sa(l).poke(v.sa.U); dut.io.sb(l).poke(v.sb.U) }
          pend.enqueue((g, k))
        } else dut.io.in_valid.poke(false.B)
        dut.clock.step()
      }
    }
    println(s"RESULT NvFp4ScaleAcc latency=4 sequences=$totalSeqs blocks=$totalSteps lane-steps-checked=$checked mismatches=$mism")
    assert(mism == 0 && checked >= totalSteps)
  }

  test("Fp32AccAdd: random FP32 operand pairs (incl. subnormals, big exponent gaps, cancellation) vs JVM float add") {
    val rng = new scala.util.Random(42)
    var mism = 0; var n = 0
    def canon(f: Float): Long = if (f.isNaN) 0x7fc00000L else java.lang.Float.floatToRawIntBits(f).toLong & 0xffffffffL
    simulate(new Fp32AccAdd) { dut =>
      def one(a: Int, b: Int): Unit = {
        dut.io.acc.poke((a.toLong & 0xffffffffL).U); dut.io.blk.poke((b.toLong & 0xffffffffL).U)
        val got = dut.io.sum.peek().litValue.toLong
        val exp = canon(java.lang.Float.intBitsToFloat(a) + java.lang.Float.intBitsToFloat(b))
        n += 1
        if (got != exp) { mism += 1; if (mism < 10) println(f"MISMATCH a=$a%08x b=$b%08x got=$got%08x exp=$exp%08x") }
      }
      for (_ <- 0 until 200000) {
        val a = rng.nextInt()
        val mode = rng.nextInt(4)
        val b = mode match {
          case 0 => rng.nextInt()                                              // unrelated
          case 1 => a ^ 0x80000000 ^ (rng.nextInt(64))                         // near-opposite: cancellation
          case 2 => (a & 0xff800000) + ((rng.nextInt(7) - 3) << 23) + (rng.nextInt() & 0x7fffff) // close exponents
          case _ => (rng.nextInt() & 0x807fffff) | ((rng.nextInt(60) + 98) << 23) // moderate exponents
        }
        one(a, b)
      }
    }
    println(s"RESULT Fp32AccAdd checked=$n mismatches=$mism")
    assert(mism == 0)
  }
}
