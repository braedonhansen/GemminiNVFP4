package nvfp4pe

import chisel3._
import chisel3.simulator.EphemeralSimulator._
import org.scalatest.funsuite.AnyFunSuite

import java.nio.file.{Files, Paths}

/** ChiselSim tests of NvFp4Mesh against refmodel/vectors/mesh_passes_d{4,16}.txt (exact integer block sums
  * from refmodel.hw_dot.mesh_block_sums). A "pass" is one K-block: A (M x K) times B (K x N), M = N = 2*dim,
  * K = dim. All passes of a test run back-to-back through one simulation with the weights of pass q+1 being
  * preloaded (into the idle c1/c2 buffer) while pass q computes, exactly like consecutive Gemmini mesh requests.
  */
class NvFp4MeshSpec extends AnyFunSuite {

  case class Pass(name: String, a: Array[Array[Int]], b: Array[Array[Int]], c: Array[Array[Int]])

  private def vecPath(file: String) = {
    val rel = "refmodel/vectors/" + file
    Seq("../../" + rel, rel, "../" + rel).map(Paths.get(_)).find(Files.exists(_))
      .getOrElse(fail(s"cannot find $rel from ${Paths.get("").toAbsolutePath}"))
  }

  private def loadPasses(file: String): Seq[Pass] = {
    val lines = new String(Files.readAllBytes(vecPath(file)), "UTF-8").split("\n").map(_.trim).filter(_.nonEmpty).toVector
    val out = Seq.newBuilder[Pass]
    var i = 0
    def mat(n: Int) = { val m = Array.tabulate(n)(j => lines(i + j).split(" ").map(_.toInt)); i += n; m }
    while (i < lines.length) {
      val h = lines(i).split(" "); assert(h(0) == "PASS"); i += 1
      val (m, k, n) = (h(2).toInt, h(3).toInt, h(4).toInt)
      val a = mat(m); val b = mat(k); val c = mat(m)
      out += Pass(h(1), a, b, c)
    }
    out.result()
  }

  /** Runs all passes back to back. Returns (outputs checked, mismatches, number of passes). */
  private def runMesh(dim: Int, tileLatency: Int, passes: Seq[Pass], gap: Int): (Int, Int) = {
    val L = tileLatency + 1
    val T = passes.size
    val period = dim + gap
    val total = (T + 1) * period + 2 * dim * L + 8
    // per-cycle input schedule
    val aIn   = Array.fill(total, dim)(0)
    val dIn   = Array.fill(total, dim)(0)
    val prop  = Array.fill(total, dim)(false)
    val valid = Array.fill(total, dim)(false)
    // expected[t][c] = Some((pass index, step m))
    val expect = Array.fill[Option[(Int, Int)]](total, dim)(None)
    for (q <- 0 to T; m <- 0 until dim) {
      val base = q * period
      for (c <- 0 until dim) {
        val t = base + m + c * L
        valid(t)(c) = true
        prop(t)(c) = (q % 2 == 0) // q even: load c1, compute with c2; q odd: load c2, compute with c1
        if (q < T) { // preload: slot m carries weight row k = dim-1-m (PE row r ends up holding row r)
          val k = dim - 1 - m
          dIn(t)(c) = passes(q).b(k)(2 * c) | (passes(q).b(k)(2 * c + 1) << 4)
        }
        if (q >= 1) expect(t + L * dim)(c) = Some((q - 1, m))
      }
      if (q >= 1) for (r <- 0 until dim) {
        val t = base + m + r * L
        val p = passes(q - 1)
        aIn(t)(r) = p.a(2 * m)(r) | (p.a(2 * m + 1)(r) << 4)
      }
    }
    var mism = 0; var n = 0
    simulate(new NvFp4Mesh(dim, tileLatency)) { dut =>
      for (t <- 0 until total) {
        for (r <- 0 until dim) dut.io.in_a(r).poke(aIn(t)(r).U)
        for (c <- 0 until dim) {
          dut.io.in_d(c).poke(dIn(t)(c).U)
          dut.io.in_prop(c).poke(prop(t)(c).B)
          dut.io.in_valid(c).poke(valid(t)(c).B)
          for (k <- 0 until 4) dut.io.in_b(c)(k).poke(0.S)
        }
        for (c <- 0 until dim) expect(t)(c).foreach { case (pi, m) =>
          val ok0 = dut.io.out_valid(c).peek().litToBoolean
          if (!ok0) { mism += 1; if (mism < 10) println(s"MISMATCH out_valid low t=$t col=$c") }
          for (k <- 0 until 4) {
            val got = dut.io.out_b(c)(k).peek().litValue.toInt
            val exp = passes(pi).c(2 * m + k / 2)(2 * c + k % 2)
            n += 1
            if (got != exp) {
              mism += 1
              if (mism < 10) println(s"MISMATCH pass=${passes(pi).name} m=${2 * m + k / 2} n=${2 * c + k % 2} got=$got exp=$exp")
            }
          }
        }
        dut.clock.step()
      }
    }
    (n, mism)
  }

  private def report(tag: String, passes: Int, r: (Int, Int)): Unit =
    println(s"RESULT $tag passes=$passes outputs_checked=${r._1} mismatches=${r._2}")

  test("DIM=4: 200+ random passes (>=10k exact block sums), back-to-back, tile_latency 0") {
    val p = loadPasses("mesh_passes_d4.txt")
    val r = runMesh(4, 0, p, 0)
    report("mesh_d4_lat0", p.size, r)
    assert(r._1 >= 10000, s"only ${r._1} outputs checked")
    assert(r._2 == 0)
  }

  test("DIM=4: same passes with idle gaps between passes and tile_latency 1 (MX default config)") {
    val p = loadPasses("mesh_passes_d4.txt")
    val r1 = runMesh(4, 0, p, 3)
    report("mesh_d4_lat0_gap3", p.size, r1)
    val r2 = runMesh(4, 1, p, 0)
    report("mesh_d4_lat1", p.size, r2)
    assert(r1._2 == 0 && r2._2 == 0)
  }

  test("DIM=16: refmodel's 67 blocks (3 diagonal passes) + corner passes + random, back-to-back") {
    val p = loadPasses("mesh_passes_d16.txt")
    val r = runMesh(16, 0, p, 0)
    report("mesh_d16_lat0", p.size, r)
    // both 13-bit extremes were actually exercised
    val all = p.flatMap(_.c.flatten)
    assert(all.contains(2304) && all.contains(-2304))
    assert(r._2 == 0)
  }

  test("DIM=16: tile_latency 1 (two registers per hop, as in defaultMxFPConfig) with gaps") {
    val p = loadPasses("mesh_passes_d16.txt").take(12)
    val r = runMesh(16, 1, p, 2)
    report("mesh_d16_lat1_gap2", p.size, r)
    assert(r._2 == 0)
  }
}
