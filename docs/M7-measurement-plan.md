# M7 measurement plan: accuracy and energy

Status: **PLAN ONLY, not started** (2026-10-21). Replaces the short D8 list in `docs/M6-design-debates.md`.
Decisions marked **(open)** need the user's answer before the matching checkpoint runs.

## Thesis to test
NVFP4 costs about what MXFP4 costs in energy and recovers most of the accuracy gap to FP8.
The precision ordering is expected to be FP32 > FP8 > NVFP4 > MXFP4 > (INT8 depends on the data).
NVFP4 vs MXFP4 energy is a genuine open question:
- **For NVFP4:** the integer PE is 4.5-6.7x smaller (M6.2).
- **Against NVFP4:**
  - the FP32 accumulator is twice as wide as BF16;
  - 16-element blocks double the scale traffic;
  - it needs an E4M3xE4M3 scale multiply where MX only adds exponents;
  - it writes FP32 outputs.

## Configs compared
Rule (user, 2026-10-21): **stock stays exactly stock.** This is a design-to-design, full-stack comparison. Each design runs on its own unmodified tree and software stack (Chipyard, Gemmini, libgemmini/Spike, rocc-tests), in the configuration its authors ship as the base.

| Name | Tree | Chipyard config | Inputs | Block scale | Per-tensor scale | Accumulator | DIM | spad / acc |
|---|---|---|---|---|---|---|---|---|
| FP32 (accuracy ceiling) | `~/chipyard` (upstream Gemmini 8c3f9923) | `FPGemminiRocketConfig` (`GemminiFP32DefaultConfig`) | FP32 | none | none needed | FP32 | **4** | 256 / 64 KiB |
| INT8 (stock default) | `~/chipyard` (upstream 8c3f9923) | `GemminiRocketConfig` (`DefaultGemminiConfig`) | INT8 | none | yes: software quantizes, hardware `mvin_scale` + `acc_scale` requant at mvout | INT32 | 16 | 256 / 64 KiB |
| MXFP8 E4M3 | `~/chipyard-mx` (266c593f) | `MxE4M3OnlyGemminiRocketConfig` | E4M3 | E8M0 / 32 | **none** (OCP MX has none; MX tests pass `ACC_SCALE_IDENTITY`) | `MxFloat(8,8,4)` (BF16-style) | 16 | 256 / 64 KiB |
| MXFP4 | `~/chipyard-mx` (266c593f) | `MxFp4OnlyGemminiRocketConfig` | E2M1 | E8M0 / 32 | **none** | BF16-style + in-array rounding ramp | 16 | 256 / 64 KiB |
| NVFP4 (ours) | `~/chipyard-mx` branch `nvfp4` | `NvFp4GemminiRocketConfig` | E2M1 | E4M3 / 16 | yes: FP32 `acc_scale` at mvout (D6) | FP32 | 16 | 256 / 128 KiB (same entry count, FP32 entries) |

- **Why `~/chipyard` for the stock designs:** the MX fork edits stock files. Relative to 8c3f9923 it changes `Configs.scala` (halves the INT8 default to 128/32 KiB, adds `use_mx_scaling`), `PE.scala` and `Arithmetic.scala`. So INT8 or FP32 built from the MX tree would not be stock.
- **FP32 stays at DIM=4.** Upstream ships no 16x16 floating-point config: FP32, FP16 and BF16 are 4x4, and `BF16Default8Config` is 8x8. It's compared at its stock size, and per-MAC energy is the like-for-like metric. Cycles will be about 16x higher by design.
- SRAM capacities match across the stock designs (256/64 KiB). The NVFP4 accumulator has the same number of entries as the others, with FP32 entries.
- Each design runs the workload through its own software (stock: `tiled_matmul_auto`/`gemmini_loop_ws`; MX: its rocc-tests style; NVFP4: our `nvfp4_e2e_mnk`), with the same shapes and the same source matrices.
- Still open:
  - **C3** output policy (NVFP4 writes FP32, INT8 can requant to 1 B). Recommended: report both full-width and native.
  - **C4** optional stock BF16 (4x4).

## Why the whole Gemmini block, not just the array
Per-config activity outside the mesh is not identical, so it can't be ignored:
- Operand bytes per element:
  - INT8 1 B
  - MXFP8 1 B + 1/32 B scale
  - MXFP4 0.5 B + 1/32 B
  - NVFP4 0.5 B + 1/16 B (plus 2 tensor scalars)
  - FP32 4 B
- Accumulator entry width: INT32, MX BF16-style, FP32. Output width is 1-4 B depending on C3.
- Scale loading: MX tests load scales through `gemmini_mx_load_scales` *and* CPU MMIO writes (`load_scale_factors` to `GEMMINI_SF_MEM_A/B`), so part of the work runs on Rocket. The harness must use one scale path for MX and NVFP4, or account for it.
- NVFP4 FP32 mvout currently goes through the scratchpad (software route), which adds spad traffic.

Scope: all of Gemmini (controller, DMA, scratchpad, accumulator, scale memory, mesh, (re)quantizers) plus a separate DRAM line item (bytes moved x pJ/bit). Rocket and the uncore are excluded, and their share of the work is reported as cycles only.

---

## M7.A Accuracy (plan)
Cheap: Python plus Spike, no RTL changes. Two levels.

**Level F (format):** quantize with each format's standard recipe, dequantize, multiply in FP64, compare against an FP64 matmul of the unquantized inputs. This measures what each *format* can do.

**Level H (hardware):** each config's real arithmetic (accumulation order, rounding ramp, accumulator width). This measures what each *implementation* does.
- NVFP4: existing refmodel (already bit-exact to Spike and RTL).
- INT8 (stock): exact INT32 accumulation, then the `acc_scale` step. Use full-width INT32 mvout as M4 did, so the output requantization is a separate, labelled step.
- FP32: Spike / hardfloat ordering. The error should be about FP32 rounding, and is the ceiling.
- MXFP4 / MXFP8: port libgemmini's MX functional model (BF16-style acc + per-row ramp) to Python. Prove it bit-exact against Spike on at least 20 matrices per format before trusting it. If the port fails, run the sweeps through Spike directly (slower, but exact by construction).

Recipes:
- NVFP4: refmodel `quant.py`. Tensor scale = amax/(6*448), E4M3 block scale = block amax/6, E2M1 RNE.
- MX: OCP MX v1.0. Shared exponent = floor(log2(block amax)) - emax_elem (E2M1: 2, E4M3: 8), elements RNE with saturation. **Check this matches how the MX branch's test data was generated** (find its generator script in rocc-tests).
- INT8: per-tensor symmetric amax/127, RNE, clamp. Per-channel is an optional extra line.

Inputs, each with 10 seeds:
- Gaussian
- Laplace and Student-t (heavy tails)
- outlier channels (a few columns x100, the LLM activation pattern)
- the existing `tiny_transformer`
- **(open)** real weights and activations from a small open model. This needs a download (~0.5 GB for GPT-2 small), so ask first.

Shapes:
- K sweep 16, 64, 256, 1024, 4096, 16384 (long K is where BF16 accumulation shows)
- M=N=64

Metrics: SQNR (dB), relative Frobenius error, max abs/rel error, cosine similarity. For the transformer: logit KL and top-1 agreement. Report mean ± 95% CI over seeds.

Ablations (Level H): NVFP4 with a BF16-style accumulator, and MXFP4 with an FP32 accumulator. These split each format's error into quantization (scale format, block size) versus accumulation.

Checks and negative controls:
- No-quantization path gives error exactly 0.
- Each quantizer round-trips its own representable values exactly.
- The MX Python port is bit-exact against Spike, and a deliberately changed rounding mode breaks that match.
- Every metric script fails when it compared 0 elements (AGENT_LOOP rule).

Deliverables: `refmodel/mx.py`, `refmodel/int8.py`, `refmodel/accuracy_sweep.py` + tests, `docs/M7-accuracy-results.md` (tables, SQNR vs K plots).

---

## M7.P Power and energy (plan, needs setup first)

### What the flow is
Nothing in the environment estimates power today: we have Verilator and Yosys AIG counts, but no cell library, no activity annotation and no SRAM models. The standard open-source flow has five stages:

1. **RTL out of Chipyard.** The Verilog is already produced by the sim build (`sims/verilator/generated-src/<config>/gen-collateral`). The power top is the Gemmini module, not the whole SoC. Chipyard's `vlsi/` flow (Hammer) can set a submodule as the VLSI top.
2. **SRAM macros.**
   - Gemmini's scratchpad, accumulator and scale memories are Chisel `SyncReadMem`s. Left alone, synthesis turns 256 KiB into about 2 M flip-flops, which neither fits in RAM nor gives a meaningful energy.
   - Chipyard's MacroCompiler maps them onto a PDK's SRAM macros, which synthesis then treats as black boxes.
   - Their energy comes from the macro's liberty file if it models power. Otherwise it's access counts x energy/access from a memory model (OpenRAM, CACTI), clearly labelled.
3. **Synthesis to standard cells** (Yosys, at one fixed clock target for every config). Logic synthesis alone is enough for *relative* comparisons. Place-and-route (OpenROAD) adds wire capacitance and a clock tree, which matters for absolute numbers. Recommended: synthesis-only first, with P&R on one config to measure how much it shifts the numbers.
4. **Switching activity from simulation.**
   - Verilator writes an FST/VCD waveform of the Gemmini hierarchy (Chipyard's `run-binary-debug` targets), only over the kernel window. Trigger it from Gemmini going busy or a cycle marker, so boot and data setup aren't counted.
   - OpenSTA reads it (`read_vcd -scope`, or SAIF) and annotates flip-flops and ports. Activity on combinational nets is then *propagated* statistically.
   - The more accurate alternative is gate-level simulation: record Gemmini's RoCC + TileLink port traffic in the RTL sim and replay it into the synthesized netlist. That's much slower and more work, so it's kept for spot-checking one workload.
5. **Power report.** OpenSTA `report_power` gives internal, switching and leakage power per instance, grouped by hierarchy (mesh, spad, acc, scale mem, DMA, controller, requant). Energy = average power x kernel cycles / f.
   - DRAM: count bytes at the Gemmini memory port, multiply by a cited pJ/bit, and report it as a separate line.
   - Clock gating: Gemmini has a `clock_gate` config option. Check which configs enable it, because without gating, clock power on idle flip-flops dominates and flattens differences.

### Tools and PDK: Cadence on the school servers (user, 2026-10-21)
The user has Cadence access on school servers, currently used for Virtuoso through MobaXterm (SSH + X11).
- **Virtuoso is the custom/analog layout tool, not the digital flow.** The flow above needs the digital tools.
- **Inventory to collect (P1, open):**
  - Genus (synthesis)
  - Joules or Voltus (power)
  - Xcelium (gate-level replay, optional)
  - Innovus (optional P&R)
  - the PDK the school licenses
  - its standard-cell libraries with power-characterized .lib files
  - an SRAM compiler or macros (if not, a memory model fills in)

  Commands to run: `which genus joules voltus innovus xrun`, plus the PDK directory listing.
- With these, Chipyard's Hammer drives Genus/Innovus/Joules from YAML. Check whether the Cadence tool plugins ship in our Hammer version.
- Without Genus/Joules on the servers, the fallback is the open flow below (sky130 + Yosys + OpenSTA, run locally).
- **Access (P2, open).** Plain `ssh` from WSL may be enough:
  - The user signs in once in their own terminal (keys or 2FA). An SSH `ControlMaster` socket then lets the agent run batch commands (`genus -batch`, `joules`) and `scp` the Verilog and waveforms, without the agent ever handling a password.
  - A MobaXterm plugin is a separate project and only needed if direct SSH isn't allowed (e.g. a gateway that only allows interactive sessions).
  - Check the school's rules on automated jobs and on publishing results from a foundry PDK. NDAs often allow normalized or relative numbers but not absolute ones.

Open-source fallback PDKs:
| PDK | Node | Support | SRAMs | Notes |
|---|---|---|---|---|
| sky130 | 130 nm | Chipyard documents a Hammer + Yosys + OpenROAD tutorial (re-check on 1.14.0) | Sram22 macros through Hammer (check that their .lib carries power) | Most reliable open path |
| ASAP7 | 7 nm predictive | OpenROAD-flow-scripts | fakeram, no power | SRAM energy must be modelled |
| Nangate45 | 45 nm | OpenROAD-flow-scripts | fakeram45, no power | Weakest SRAM story |

### Compute
- Simulation: the NVFP4 workloads are 2.5k-18k cycles, so the waveform runs are minutes. MX `fp4_64x64` is 104k cycles, which is fine if only the Gemmini scope is dumped.
- Synthesis is the risk. M6.2's Yosys run on the full MX array didn't finish within the 12 GB WSL limit, and a DIM=16 FP32 mesh is larger still. On the school servers this is likely a non-issue. For the open fallback, a high-memory CPU cloud pod (64+ GB) would be needed, with the price quoted first.

### Workloads
- One harness for every config:
  - DMA in A and B (plus scales where the format has them), compute, mvout;
  - built on `gemmini_loop_ws` where each config supports it;
  - same shapes: 64x64x512, 128x128x512, K sweep 128-2048.
- The input data comes from the M7.A matrices (Gaussian + outliers), because power depends on the data.
- Each workload's result must be checked against its model before its activity is used, so energy is never measured on a run that computed the wrong thing.

### Checks for the power flow
- **Data dependence:** all-zero inputs must cut mesh switching power well below random inputs. If not, the activity annotation isn't working.
- **Idle:** the idle-Gemmini window gives roughly leakage + clock only.
- **Sanity against a reference:** compare the INT8 Gemmini numbers in magnitude with the published Gemmini results (DAC 2021). Different nodes mean the check is rough only.
- **Stability:** re-running the same workload gives the same power. Shrinking the window to half the kernel changes energy roughly in proportion.
- **Coverage:** every SRAM macro and every hierarchy group shows up in the report, and a report missing a group fails.

### Order of work
- P.0: tool/PDK inventory on the school servers and an access method. Then synthesize **stock INT8 Gemmini** (from `~/chipyard`) as the first target. It's the best-trodden design.
- P.1: activity flow on INT8 (waveform window, OpenSTA annotation, data-dependence check).
- P.2: SRAM energy (macro liberty power, or access-count model).
- P.3: repeat for stock FP32 (4x4), MXFP8, MXFP4, NVFP4.
- P.4: optional P&R on one config to measure the clock-tree and wire effect.
- P.5: energy table + the energy-per-MAC vs SQNR Pareto plot, combined with M7.A.

## Baselines (user, 2026-10-21)
Stock Gemmini at maximum accuracy (FP32) and stock INT8 are both required baselines, for accuracy and for power, built from upstream `~/chipyard` unmodified.
