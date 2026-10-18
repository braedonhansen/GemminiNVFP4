package nvfp4pe

import chisel3._
import chisel3.util._

/** Weight-stationary NVFP4 mesh (M6.2 Phase A1): a dim x dim array of V6 `NvFp4PE`s with exact 13-bit
  * integer partial sums, laid out like Berkeley's MX Gemmini mesh (gemmini Mesh.scala / PE.scala @ 266c593f,
  * tileRows = tileColumns = 1; see docs/M6.2-integration-plan.md for file:line refs).
  *
  * Pairing and flow (identical to MX FP4 mode):
  *  - Every mesh-row input (activation) and every mesh-column weight is one byte = TWO E2M1 codes.
  *    Low nibble = element 0, high nibble = element 1 (Controller.scala:999 expand()).
  *  - PE lane k = act[k/2] x wei[k%2]  ->  [a0w0, a0w1, a1w0, a1w1]  (MxPE.scala:34), which is NvFp4PE's d00,d01,d10,d11.
  *    So the two activation nibbles are two different output ROWS (M) and the two weight nibbles two output COLUMNS (N).
  *  - Activations flow west -> east along a mesh row, partial sums flow north -> south down a mesh column,
  *    weights are preloaded north -> south through the double-buffered c1/c2 registers (PE.scala:139-151).
  *  - Between PEs there are `L = tileLatency + 1` registers on the a, b(partial sum), d(weight), propagate and valid
  *    paths, exactly like Mesh.scala (ShiftRegister for a and valid, valid-gated Pipe for b, d and propagate).
  *  - The partial sum is Vec(4, SInt(13)) per column instead of MX's per-row FP ramp. Each lane is exact:
  *    |sum| <= 16 * 144 = 2304 < 2^12 (D2).
  *
  * Skew/de-skew is NOT in this module (MX does it in MeshWithDelays, which we do not reimplement here): in_a(r) must
  * be delayed r*L cycles, and in_b/in_d/in_prop/in_valid(c) delayed c*L cycles, relative to the first row of a pass.
  * The ChiselSim test drives exactly that schedule. Outputs appear at the bottom row (out_b(c)) with
  * `mesh_output_delay = 0`, `L*dim` cycles after the same-skewed top-row entry of the corresponding step.
  */
class NvFp4MeshPE extends Module {
  val io = IO(new Bundle {
    val in_a      = Input(UInt(8.W))             // {a1, a0}
    val in_b      = Input(Vec(4, SInt(NvFp4.ColW.W))) // partial sums from the PE above
    val in_d      = Input(UInt(8.W))             // {w1, w0} being preloaded
    val in_prop   = Input(Bool())                // PE.scala: propagate
    val in_valid  = Input(Bool())
    val out_a     = Output(UInt(8.W))
    val out_b     = Output(Vec(4, SInt(NvFp4.ColW.W)))
    val out_c     = Output(UInt(8.W))            // preload chain (the buffer being loaded)
    val out_prop  = Output(Bool())
    val out_valid = Output(Bool())
  })

  // PROPAGATE (=1): c1 is being loaded, c2 is the active weight. COMPUTE (=0): c2 is being loaded, c1 is active.
  val c1 = Reg(UInt(8.W))
  val c2 = Reg(UInt(8.W))
  val prop = io.in_prop

  val pe = Module(new NvFp4PE)
  val w = Mux(prop, c2, c1)
  pe.a0 := io.in_a(3, 0); pe.a1 := io.in_a(7, 4)
  pe.w0 := w(3, 0);       pe.w1 := w(7, 4)
  pe.c00 := io.in_b(0);   pe.c01 := io.in_b(1)
  pe.c10 := io.in_b(2);   pe.c11 := io.in_b(3)
  io.out_b(0) := pe.d00;  io.out_b(1) := pe.d01
  io.out_b(2) := pe.d10;  io.out_b(3) := pe.d11

  io.out_a := io.in_a
  io.out_prop := prop
  io.out_valid := io.in_valid
  io.out_c := Mux(prop, c1, c2)

  when(io.in_valid) {
    when(prop) { c1 := io.in_d }.otherwise { c2 := io.in_d }
  }
}

class NvFp4Mesh(val dim: Int = 16, val tileLatency: Int = 0) extends Module {
  require(dim >= 1 && tileLatency >= 0)
  override def desiredName = s"NvFp4Mesh_d${dim}_l$tileLatency"

  val L = tileLatency + 1
  private def lanes = Vec(4, SInt(NvFp4.ColW.W))

  val io = IO(new Bundle {
    val in_a      = Input(Vec(dim, UInt(8.W)))   // one pair per mesh row
    val in_b      = Input(Vec(dim, lanes))       // top partial sums (normally 0)
    val in_d      = Input(Vec(dim, UInt(8.W)))   // one weight pair per mesh column
    val in_prop   = Input(Vec(dim, Bool()))
    val in_valid  = Input(Vec(dim, Bool()))
    val out_b     = Output(Vec(dim, lanes))      // bottom row: exact block sums, 4 lanes per column
    val out_valid = Output(Vec(dim, Bool()))
  })

  private def pipe[T <: Data](valid: Bool, t: T): T =
    chisel3.withReset(false.B) { Pipe(valid, t, L).bits }

  val mesh = Seq.fill(dim, dim)(Module(new NvFp4MeshPE))

  // a: west -> east, free-running registers (Mesh.scala:110 non-MX path)
  for (r <- 0 until dim) {
    mesh(r).foldLeft(io.in_a(r)) { case (in_a, pe) =>
      pe.io.in_a := ShiftRegister(in_a, L)
      pe.io.out_a
    }
  }
  // b (partial sums), d (weights), propagate: north -> south, valid-gated pipes (Mesh.scala:117-160)
  for (c <- 0 until dim) {
    val col = mesh.map(_(c))
    col.foldLeft((io.in_b(c), io.in_valid(c))) { case ((b, v), pe) =>
      pe.io.in_b := pipe(v, b)
      (pe.io.out_b, pe.io.out_valid)
    }
    col.foldLeft((io.in_d(c), io.in_valid(c))) { case ((d, v), pe) =>
      pe.io.in_d := pipe(v, d)
      (pe.io.out_c, pe.io.out_valid)
    }
    col.foldLeft((io.in_prop(c), io.in_valid(c))) { case ((p, v), pe) =>
      pe.io.in_prop := pipe(v, p)
      (pe.io.out_prop, pe.io.out_valid)
    }
    col.foldLeft(io.in_valid(c)) { case (v, pe) =>
      pe.io.in_valid := ShiftRegister(v, L)
      pe.io.out_valid
    }
    io.out_b(c) := col.last.io.out_b
    io.out_valid(c) := col.last.io.out_valid
  }
}

/** Emit SystemVerilog:  sbt "runMain nvfp4pe.ElaborateMesh <outdir> [dim] [tileLatency]" */
object ElaborateMesh extends App {
  val dir  = if (args.length > 0) args(0) else "build"
  val dim  = if (args.length > 1) args(1).toInt else 16
  val lat  = if (args.length > 2) args(2).toInt else 0
  val opts = Array("-disable-all-randomization", "-strip-debug-info", "--lowering-options=disallowLocalVariables,noAlwaysComb")
  _root_.circt.stage.ChiselStage.emitSystemVerilogFile(new NvFp4Mesh(dim, lat), Array("--target-dir", dir), opts)
}
