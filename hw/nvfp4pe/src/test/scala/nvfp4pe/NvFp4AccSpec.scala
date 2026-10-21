package nvfp4pe

import chisel3._
import chisel3.simulator.EphemeralSimulator._
import org.scalatest.funsuite.AnyFunSuite

import java.io.{BufferedReader, InputStreamReader}
import java.nio.file.{Files, Path, Paths}
import java.util.zip.GZIPInputStream
import scala.collection.mutable

/** Both pipelined adders side by side, same inputs. */
class AddCmp extends Module {
  val io = IO(new Bundle {
    val acc = Input(UInt(32.W)); val blk = Input(UInt(32.W))
    val sum2 = Output(UInt(32.W)); val sum1 = Output(UInt(32.W))
  })
  val a2 = Module(new Fp32AccAdd2); val a1 = Module(new Fp32AccAdd)
  a2.io.acc := io.acc; a2.io.blk := io.blk; a1.io.acc := io.acc; a1.io.blk := io.blk
  io.sum2 := a2.io.sum
  io.sum1 := RegNext(RegNext(a1.io.sum)) // 1-cycle adder delayed by 2 to line up
}

/** M6.3 Phase B step B0: 2-stage FP32 adder + same-address accumulate pipe (stall on RAW hazard). */
class NvFp4AccSpec extends AnyFunSuite {

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

  private def canon(f: Float): Long = if (f.isNaN) 0x7fc00000L else java.lang.Float.floatToRawIntBits(f).toLong & 0xffffffffL

  test("Fp32AccAdd2: 2-cycle latency, bit-exact vs JVM float and vs the 1-cycle Fp32AccAdd (300k random pairs, streaming)") {
    val rng = new scala.util.Random(4242)
    val N = 300000
    val as = new Array[Int](N); val bs = new Array[Int](N)
    for (i <- 0 until N) {
      val a = rng.nextInt()
      val b = rng.nextInt(4) match {
        case 0 => rng.nextInt()
        case 1 => a ^ 0x80000000 ^ (rng.nextInt(64))
        case 2 => (a & 0xff800000) + ((rng.nextInt(7) - 3) << 23) + (rng.nextInt() & 0x7fffff)
        case _ => (rng.nextInt() & 0x807fffff) | ((rng.nextInt(60) + 98) << 23)
      }
      as(i) = a; bs(i) = b
    }
    // specials
    val sp = Seq(0, 0x80000000, 0x7f800000, 0xff800000, 0x7fc00000, 0x7f800001, 0x00000001, 0x007fffff, 0x7f7fffff, 0x3f800000)
    var mism = 0; var n = 0; var mism1 = 0
    simulate(new AddCmp) { dut =>
      val total = N + sp.length * sp.length
      def inA(i: Int) = if (i < N) as(i) else sp((i - N) / sp.length)
      def inB(i: Int) = if (i < N) bs(i) else sp((i - N) % sp.length)
      for (t <- 0 until total + 3) {
        if (t >= 2 && t - 2 < total) {
          val i = t - 2
          val exp = canon(java.lang.Float.intBitsToFloat(inA(i)) + java.lang.Float.intBitsToFloat(inB(i)))
          val got = dut.io.sum2.peek().litValue.toLong
          val got1 = dut.io.sum1.peek().litValue.toLong
          n += 1
          if (got != exp) { mism += 1; if (mism < 10) println(f"MISMATCH a=${inA(i)}%08x b=${inB(i)}%08x got=$got%08x exp=$exp%08x") }
          if (got != got1) mism1 += 1
        }
        if (t < total) { dut.io.acc.poke((inA(t).toLong & 0xffffffffL).U); dut.io.blk.poke((inB(t).toLong & 0xffffffffL).U) }
        dut.clock.step()
      }
    }
    println(s"RESULT Fp32AccAdd2 latency=2 checked=$n mismatches_vs_JVM=$mism mismatches_vs_1cycle=$mism1")
    assert(mism == 0 && mism1 == 0 && n >= 200000)
  }

  test("NvFp4RmwPipe: back-to-back same-address accumulate (stall on RAW), every stored row checked vs refmodel float32 order") {
    // sequences from the refmodel acc vectors (acc after each block, starting at +0)
    val seqs = mutable.ArrayBuffer[mutable.ArrayBuffer[V]]()
    for (l <- lines("acc_seq.txt.gz")) {
      if (l == "S") seqs += mutable.ArrayBuffer[V]()
      else { val f = l.split(' '); seqs.last += V(f(0).toInt, f(1).toInt, f(2).toInt, hex(f(3))) }
    }
    // M6.3C: the first block of a pass also goes through the adder (+0 + blk), so there are no exclusions: -0-first sequences included.
    val skipped = 0
    val usable = seqs
    val Entries = 2; val Lanes = 4; val PerRow = Entries * Lanes
    // group PerRow sequences of equal length per row
    val groups = usable.groupBy(_.length).toSeq.sortBy(_._1).flatMap { case (_, ss) =>
      ss.grouped(PerRow).map(g => (0 until PerRow).map(i => g(math.min(i, g.length - 1))).toArray).toSeq
    }
    val rng = new scala.util.Random(99)
    val order = rng.shuffle(groups)
    val Streams = 3
    val Depth = 8
    val totalSeqs = usable.length
    val totalWrites = order.map(_(0).length).sum
    var mism = 0L; var checked = 0L; var stalls = 0L; var sameAddrBackToBack = 0L
    val AddrOf = Array(1, 3, 6)

    case class Exp(addr: Int, vals: Array[Long])
    val expQ = mutable.Queue[Exp]()
    val finalExp = new Array[Array[Long]](Depth)

    simulate(new NvFp4AccBank(Entries, Lanes, Depth)) { dut =>
      var next = 0
      val cur = Array.fill[Array[mutable.ArrayBuffer[V]]](Streams)(null)
      val pos = Array.fill(Streams)(0)
      def load(s: Int): Unit = { if (next < order.length) { cur(s) = order(next); pos(s) = 0; next += 1 } else cur(s) = null }
      for (s <- 0 until Streams) load(s)
      // scale bytes for the write fired in the previous cycle
      var pendScale: Option[(Array[V])] = None // per-lane V of the write fired last cycle
      var lastAddr = -1
      def laneV(g: Array[mutable.ArrayBuffer[V]], k: Int): Array[V] = (0 until PerRow).map(l => g(l)(k)).toArray
      var cycles = 0L
      var done = false
      var drain = 0
      while (!done) {
        // 1. scale response for last cycle's fire
        pendScale match {
          case Some(vs) =>
            for (e <- 0 until Entries) {
              for (j <- 0 until Lanes) { dut.io.sa(e)(j).poke(vs(e * Lanes + j).sa.U); dut.io.sb(e)(j).poke(vs(e * Lanes + j).sb.U) }
            }
          case None => ()
        }
        pendScale = None
        // 2. pick a request
        val live = (0 until Streams).filter(s => cur(s) != null)
        var fired = false
        if (live.nonEmpty && rng.nextInt(10) < 8) {
          val s = live(rng.nextInt(live.length))
          val g = cur(s); val k = pos(s)
          val addr = AddrOf(s)
          val acc = k > 0
          val vs = laneV(g, k)
          for (e <- 0 until Entries) {
            var w = BigInt(0)
            for (j <- 0 until Lanes) w = w | (BigInt(vs(e * Lanes + j).isum & 0xffff) << (16 * j))
            dut.io.data(e).poke(w.U)
          }
          dut.io.addr.poke(addr.U); dut.io.acc.poke(acc.B)
          val rdy = dut.io.ready.peek().litToBoolean
          if (rdy) {
            dut.io.fire.poke(true.B); fired = true
            if (addr == lastAddr) sameAddrBackToBack += 1
            // expected stored row
            expQ.enqueue(Exp(addr, vs.map(_.exp)))
            pendScale = Some(vs)
            pos(s) += 1
            if (pos(s) == g(0).length) { finalExp(addr) = g.map(_.last.exp); load(s) }
          } else stalls += 1
          lastAddr = if (fired) addr else lastAddr
        }
        if (!fired) { dut.io.fire.poke(false.B); lastAddr = -1 }
        // 3. check write port (before the clock edge)
        if (dut.io.wr_valid.peek().litToBoolean) {
          val ex = expQ.dequeue()
          val a = dut.io.wr_addr.peek().litValue.toInt
          assert(a == ex.addr, s"write address order broke: got $a expected ${ex.addr}")
          for (e <- 0 until Entries; j <- 0 until Lanes) {
            val got = (dut.io.wr_data(e).peek().litValue >> (32 * j)).toLong & 0xffffffffL
            val exp = ex.vals(e * Lanes + j)
            checked += 1
            if (got != exp) { mism += 1; if (mism < 10) println(f"MISMATCH addr=$a e=$e lane=$j got=$got%08x exp=$exp%08x") }
          }
        }
        dut.clock.step()
        cycles += 1
        if (live.isEmpty && !fired) { drain += 1; if (drain > 12) done = true } else drain = 0
      }
      assert(expQ.isEmpty, s"${expQ.size} writes never landed")
      // final rows read back from the SRAM
      for (a <- AddrOf if finalExp(a) != null) {
        dut.io.dbg_addr.poke(a.U)
        for (e <- 0 until Entries; j <- 0 until Lanes) {
          val got = (dut.io.dbg_data(e).peek().litValue >> (32 * j)).toLong & 0xffffffffL
          if (got != finalExp(a)(e * Lanes + j)) mism += 1
        }
      }
      println(s"cycles=$cycles")
    }
    println(s"RESULT NvFp4RmwPipe sequences=$totalSeqs (skipped -0-first: $skipped) writes=$totalWrites lane-values-checked=$checked stalls(cycles ready low)=$stalls back-to-back-same-addr-accepted=$sameAddrBackToBack mismatches=$mism")
    assert(mism == 0 && checked > 0 && stalls > 0)
  }
}
