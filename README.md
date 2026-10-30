# NVFP4 for Gemmini

This project adds NVIDIA's **NVFP4** 4-bit floating-point format to [Gemmini](https://github.com/ucb-bar/gemmini), the open-source systolic-array matrix accelerator from UC Berkeley. An NVFP4 tensor is made of:

- **E2M1** values: 4 bits each, giving ±{0, 0.5, 1, 1.5, 2, 3, 4, 6}
- one **E4M3** scale per block of 16 values
- one **FP32** scale for the whole tensor

The work is built on top of Berkeley's MX Gemmini (`ucb-bar/gemmini`, branch `gemmini-mx-cleanup` @ `266c593f`, with MxGen).

Write-up: [braedonhansen.github.io/Portfolio/gemmini-nvfp4.html](https://braedonhansen.github.io/Portfolio/gemmini-nvfp4.html)

## Design

- **PEs multiply in integers.** Each E2M1 value is doubled, which maps it onto {0, 1, 2, 3, 4, 6, 8, 12}, so a product is a small exact integer. The multiplier was chosen out of six equivalent variants after synthesis (V6: shared decode, with the sign folded into the adder).
- **Blocks accumulate exactly.** Every 16-element block sums into a 13-bit signed integer per column, so nothing is rounded inside the array.
- **A scale stage converts at the array output.** A fixed-function stage multiplies each block sum by its two E4M3 scales (sA × sB). The result is exact, and it goes into an IEEE FP32 accumulator through a 2-stage pipelined adder.
- **The tensor scale is applied at mvout**, using Gemmini's `acc_scale` path with an FP32 multiplier.
- **Block scales are stored on chip.** They live in a scale SRAM that outputs raw E4M3 bytes.

The design decisions and the alternatives considered are in [docs/M6-design-debates.md](docs/M6-design-debates.md).

## Status

| Milestone | Result |
|---|---|
| M0 | Python reference model, 173 pytest checks |
| M2 | Stock Chipyard 1.14.0 + Gemmini built and passing in Verilator |
| M4 | NVFP4 in software on stock Gemmini, bit-exact in Spike and Verilator |
| M5 | Berkeley MX Gemmini brought up; its FP4 tests pass |
| M6 | **NVFP4 in hardware.** Multi-tile matmuls (up to 96×32×256 and 64×64×512) are bit-exact against the reference model in both Spike and Verilator |
| M7.A | Accuracy study comparing FP32, INT8, MXFP8, MXFP4 and NVFP4 ([results](docs/M7-accuracy-results.md)) |
| M7.P | **In progress.** Energy and area comparison in FreePDK45 with Cadence Genus/Joules. The flow now runs end to end on stock INT8 Gemmini as a smoke test ([docs/m7p/int8-stock-a](docs/m7p/int8-stock-a/README.md)) |

> **Power numbers are not done yet.** The one run so far is a flow check on the stock INT8 baseline, and its SRAMs are black boxes. The energy comparison across the five designs is still in progress.

At K = 1024 with Gaussian data, measured as hardware-level SQNR: FP32 130.5 dB, INT8 37.0, MXFP8 24.8, **NVFP4 16.8**, MXFP4 (OCP scaling) 15.6. In every condition tested, NVFP4 lands between MXFP4 and MXFP8.

[PROGRESS.md](PROGRESS.md) is the full log of milestones, decisions and verification.

## Repository layout

| Path | Contents |
|---|---|
| `refmodel/` | Python reference model: formats, quantization, hardware-order dot products, the scale stage, MX and INT8 models, export scripts for the C test headers, and accuracy sweeps |
| `refmodel/tests/` | pytest suite |
| `refmodel/vectors/` | Exported test vectors (E2M1 pairs, E4M3 table, mesh passes, scale-stage and accumulate sequences) |
| `hw/nvfp4pe/` | Chisel 6 sources for the PE, the 16×16 mesh, the scale stage and the FP32 accumulate pipe, plus ChiselSim tests and generated SystemVerilog |
| `hw/pe_variants/` | The multiplier synthesis study: six Verilog PE variants, testbenches, Yosys metrics and [results](hw/pe_variants/RESULTS.md) |
| `hw/tests/` | Bare-metal C tests for Gemmini, with generated data headers |
| `hw/power/` | Energy flow: Genus/Joules scripts and a FreePDK45 library kit (Nangate45 cells and OpenRAM SRAM banks) |
| `docs/` | Scope, design debates, integration plans and results for each milestone |
| `briefs/`, `logs/` | Task briefs and step logs (see [AGENT_LOOP.md](AGENT_LOOP.md)) |

| `patches/gemmini/` | The Gemmini RTL integration (NVFP4-only config, scale stage, FP32 accumulator, FP32 mvout) as `git format-patch` files on MX Gemmini `266c593f` |
| `patches/libgemmini/` | The bit-exact Spike model (`libgemmini_nvfp4.so`) as patches on libgemmini `87663107` |

To apply the patches in a Chipyard checkout that has MX Gemmini at `266c593f`:

```bash
cd generators/gemmini && git checkout -b nvfp4 266c593f && git am /path/to/gemmini-nvfp4/patches/gemmini/*.patch
cd software/libgemmini && git checkout -b nvfp4 87663107 && git am /path/to/gemmini-nvfp4/patches/libgemmini/*.patch
```

## Running

### Reference model (Windows, from the repo root)

```bash
python -m venv .venv
.venv\Scripts\pip install -r requirements.txt
.venv\Scripts\python -m pytest -q
```

Test headers are regenerated from the reference model. For example, `export_e2e.py [path [seed [M N K]]]`:

```bash
.venv\Scripts\python refmodel\export_e2e.py my_case_data.h 1234 64 64 512
```

The M7.A data headers (~46 MB) aren't committed. Regenerate them with `refmodel/export_m7a.py`.

### Chisel components (`hw/nvfp4pe`)

```bash
cd hw/nvfp4pe && sbt test
```

### On Gemmini (WSL2, Ubuntu 22.04)

Chipyard needs Linux and about 8.5 GB of RAM to build the Verilator simulator.

- The stock baseline lives in `~/chipyard`, using `GemminiRocketConfig`. See [hw/README.md](hw/README.md) for the M4 software flow.
- The NVFP4 config lives in `~/chipyard-mx`, using `NvFp4GemminiRocketConfig`. Its Spike extension is `spike --extension=gemmini_nvfp4`.
- The setup commands and the pinned commits for each environment are under "Environment notes" in [PROGRESS.md](PROGRESS.md).

## Verification approach

Every test is checked bit for bit against the reference model, and every check also has a **negative control**: a deliberate one-value or one-bit mutation that must make it fail. A check that ran zero vectors counts as a failure.

On top of that:

- The PE variants are formally proven equivalent with Yosys miters.
- The scale stage was checked exhaustively over all 65,536 scale pairs.

## License

BSD 3-Clause (see [LICENSE](LICENSE)), the same license Berkeley uses for Gemmini. Third-party code keeps its own license:

- hardfloat sources in `hw/nvfp4pe/src/main/scala/hardfloat/`: BSD 3-Clause
- Nangate45: Apache 2.0
- OpenRAM: BSD 3-Clause

Gemmini, Chipyard and MxGen are BSD 3-Clause (UC Regents).
