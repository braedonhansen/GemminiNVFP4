# M3: Scope of the first working NVFP4 version

Status: **DRAFT for the user's review** (2026-10-11). Based on a read-only survey of Gemmini `8c3f9923` (Chipyard 1.14.0).
Paths below are relative to `~/chipyard/generators/gemmini/src/main/scala/gemmini/`.

## The design correction
The site's plan was "integer block sums in the array, apply each block's scale once at the accumulator drain, the way INT8 applies `acc_scale`."
That only works when K = 16 (one block). For K > 16:

- Gemmini's accumulator **adds partial sums across K-tiles** (`acc` flag, `ExecuteController.scala:952`), and scaling only happens at mvout (`AccumulatorScale`, instantiated at `Scratchpad.scala:635`).
- Each K block has its **own** scales, so blocks can't be summed as integers first. The scale has to be applied **before** accumulation: scale-then-add on the array output, into an FP32 accumulator.
- The scale for output element (i, j) in block kb is `sA[i,kb] · sB[kb,j]`. This is not one scalar per row.

In weight-stationary mode this fits naturally:
- One pass of the 16×16 array reduces exactly one 16-element K block (`block_size = meshRows*tileRows`, `MeshWithDelays.scala:46`).
- `sB[kb, ·]` is a **16-wide vector that's fixed for the whole pass**, because it belongs to the preloaded weights.
- `sA[i, kb]` is **one scalar per output row**, streaming alongside the A rows.
- So the output of the array, row i, is multiplied by `sA[i]` and by a per-column `sB` vector, then added to the FP32 accumulator.

**Exactness bonus.** A block sum (≤13-bit integer) × two E4M3 scales (4-bit significands each) needs at most a 21-bit significand. That fits FP32's 24 bits, so **the per-block scaling step is exact in FP32**. The only rounding is in the FP32 additions across blocks, plus the final tensor scale. That final tensor scale `tA·tB/4` is one FP32 per matmul, which is exactly what the existing `acc_scale` at mvout already does.

## Staged plan
Each stage ends in something that runs and is checked against `refmodel/`.

| Stage | What changes | Proves | Risk |
|---|---|---|---|
| **v0: software NVFP4 on stock Gemmini** | Nothing in hardware. C test decodes E2M1 codes to doubled ints in `int8`, issues one K=16 block per compute, reads integer block sums back, and applies the scales on the CPU. | End-to-end harness: refmodel vectors → C test → Verilator/Spike → compare. Integer block sums match bit for bit. | Low |
| **v1: E2M1 PE** | New arithmetic so the PE takes raw 4-bit codes (one per byte, low nibble) and multiplies via decode + shift/mux. Array output narrowed to 13 bits. | 256-pair exhaustive unit test. v0 runs unchanged except for raw codes in memory. | Medium (Arithmetic typeclass) |
| **v2: on-chip block scaling, K = 16** | Scale stage at the array output: row scalar `sA[i]` × column vector `sB[·]`, into an FP32 accumulator. Scales delivered by a stopgap path (see open questions). | Full NVFP4 dot product on-chip for single-block K. Bit-exact vs refmodel. | Medium-high |
| **v3: K > 16** | Same scale stage, now with scale-then-accumulate across K blocks, and scales streamed per block in sync with the compute order. | Real matmul sizes. Matches refmodel within the FP32-accumulation tolerance. | High (controller sync) |
| Deferred | Packed 4-bit storage in scratchpad/DMA; dedicated `mvin_scales` instruction + ReservationStation hazard tracking for a scale SRAM. | Memory density (the 4.5-bit/value win). | High, touches many files |

**Proposed definition of "first working version": v2.** The array does real NVFP4 math with on-chip scaling, checked bit-exact on the refmodel vectors.
v0 + v1 should take days. v3 and packed storage come after.

## Why things are deferred
- **Sub-byte storage.** `inputType.getWidth / 8` appears in DMA, Scratchpad, ZeroWriter and StoreController. `GemminiConfigs.scala:326` asserts widths ∈ {8,16,32,64}, and the masks are byte-based. Storing codes one per byte wastes half the space but avoids all of that.
- **New ISA instruction.** The ReservationStation (`ReservationStation.scala:195-390`) only tracks hazards on `LocalAddr` ranges, so a separate scale SRAM would be invisible to it. Every funct code from 26 to 125 is free, but all four `CONFIG` subtypes are taken.

## Open questions (user decisions)
1. **Is v2 the right definition of "first working"?** (Recommended.) Or is v1 (PE + test) enough for a first write-up?
2. **How scales reach the array in v2:**
   - **(a) Recommended:** put scales in a reserved scratchpad region and load them with ordinary `mvin`. The RS then tracks hazards for free. The cost is a read port/arbitration question.
   - **(b)** A new scale SRAM plus a new instruction. Cleaner, but it's the most work and the RS can't see it.
3. **Arithmetic approach for v1:**
   - **(a) Recommended:** a `Float`-style parametrized Bundle plus a new `Arithmetic` instance. There's precedent in `Arithmetic.scala:328-390`.
   - **(b)** Keep `T = SInt` and decode in the load path. Simpler, but the PE math stops being the "interesting part".
4. **Test framework.** The existing Chisel unit tests use the legacy `chisel3.iotesters` and look stale (wrong `MeshWithDelays` argument order). For the PE test, use ChiselSim/svsim on Chisel 6 (recommended), or a Verilator testbench.

## Code map (for M4+)
| Concern | Where |
|---|---|
| MAC | `PE.scala:23` (`MacUnit`), OS `:115`, WS `:123` |
| Arithmetic typeclass | `Arithmetic.scala:27-49`; SInt `:93`; Float `:328-390` |
| Config types | `GemminiConfigs.scala:18-26`, width check `:105`, width assert `:326`, C header `~296-312` |
| Default config | `Configs.scala:20-60` (16×16, BOTH, SInt8/SInt20/SInt32) |
| Array instance | `ExecuteController.scala:186`; width casts `:836-838`, `:951`; acc flag `:952` |
| acc_scale | set `StoreController.scala:51,237`, `ExecuteController.scala:555`; carried `Scratchpad.scala:740` → `AccumulatorMem.scala:355` → `AccumulatorScale` |
| mvin + scale | `LoadController.scala`, `DMA.scala:53,124`, `VectorScalarMultiplier` at `Scratchpad.scala:407` |
| ISA | `GemminiISA.scala:6-44`; RS `ReservationStation.scala:313-322`; routing `Controller.scala:~490-515` |
| Unit tests | `src/test/scala/gemmini/MeshWithDelaysUnitTest.scala` (iotesters, stale) |
| C tests | `software/gemmini-rocc-tests/bareMetalC/` (`matmul_ws.c`, `mvin_scale.c`) |
