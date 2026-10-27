# M7.P job int8-stock-a: first end-to-end power run (stock INT8 Gemmini)

Date: 2026-10-27. Status: **smoke test passed.** Synthesis + activity-based power both ran on the school server.

## Setup
| Item | Value |
|---|---|
| Design | Stock Gemmini (upstream 8c3f9923, `GemminiRocketConfig`), module `Gemmini` only (no Rocket, caches or uncore) |
| SRAMs | 6 macros (4 x `mem_ext` 4096x128 scratchpad, 2 x `mem_0_ext` 512x512 accumulator) as **black boxes**: no SRAM power in this run |
| Library | OSU FreePDK45 `gscl45nm.lib` (typical), on the server |
| Tools | Genus 25.1 (synthesis), Joules 25.1 (power) |
| Clock | 5.0 ns (200 MHz), the same target for every design in M7 |
| Workload | INT8 tiled matmul 64x64x512 through stock software (`hw/tests/m7p_int8_64x64x512.c`); the test passes in RTL |
| Activity | Verilator VCD of the Gemmini scope only, kernel window 14,300 cycles (first RoCC command to the last `io_busy` fall), rescaled to the 5 ns clock |

## Synthesis (Genus, `qor.rpt`, `area_depth*.rpt`, `timing.rpt`)
- **Timing met** at 200 MHz: worst slack 0, 0 violating paths.
- **907,874 cells** (78,969 sequential), **2.92 mm^2** cell area (SRAMs excluded).
- The array (`ex_controller/mesh`) is 41% of the area. `LoopConv` (the convolution unroller, unused by matmuls) is 14%.
- Runtime about 2 h 40 min (syn_opt done at 9,599 s), 4 CPUs.
- All 6 macro instances are still present after mapping (`M7P-MACROS-AFTER-MAP 6`).

## Power (Joules, `power_total_and_l2.rpt`, `power_by_hier_l4_and_inst.rpt`)
Activity annotation from the `read_stimulus` report: inputs 100%, outputs 100%, **flops 99.96%** (78,943 / 78,969). Activity on the logic between flops is propagated by Joules.

| Block | Power (mW) | Share |
|---|---|---|
| **Gemmini total** | **341.99** | 100% |
| `ex_controller/mesh` (16x16 array + delay registers) | 184.51 | 54% |
| `spad` (scratchpad/accumulator logic, excluding the SRAMs) | 99.24 | 29% |
| `spad/acc_scale_unit` | 18.02 | 5% |
| `reservation_station` | 18.68 | 5% |
| `mod` (LoopConv, idle in this workload) | 14.30 | 4% |
| `mod_1` (LoopMatmul) | 6.37 | 2% |
| load/store controllers, counters, TLB, queues | ~11 | 3% |

- **By category:** register 251.9 mW (73.7%), logic 90.1 mW (26.3%).
- **By type:** internal 289.9 mW (84.8%), switching 37.9 mW (11.1%), leakage 14.2 mW (4.2%).
- **Derived:**
  - Kernel energy = 341.99 mW x 14,300 x 5 ns = **24.45 uJ**.
  - MACs = 64 x 64 x 512 = 2,097,152, giving **11.7 pJ/MAC** for the whole block and **6.3 pJ/MAC** for the array alone.
  - Array utilization = 8,192 ideal cycles / 14,300 = 57%.

## Caveats
- **No clock gating.** Flop internal (clock-pin) power dominates (85% internal), so idle blocks such as LoopConv still burn power. The cross-format comparison will therefore track flop count strongly.
- **Missing pieces:**
  - SRAM power (next job, with the M7.P0b OpenRAM models);
  - wire and clock-tree power (the clock tree is ideal; P&R would add it).
- **The OSU library is small (about 30 cells) and old,** so absolute numbers are rough. The Nangate45 rerun is the reference.
- Joules' SDC read rejected 6 Genus-specific commands (`set_dont_touch` forms). The clock definition was read.

## Flow fixes found on this first server run (all in `hw/power/`)
- `genus_int8.tcl`: `.current_design` is read-only in Genus 25.1, and `report_power` has no `-depth`.
- `run.csh`: the success checks now match `^M7P-` only (Genus echoes the script lines, so unanchored greps matched the source text). Added `SKIP_GENUS` for Joules-only reruns.
- `joules_int8.tcl`:
  - read the Genus netlist, not the Genus db (`read_db` couldn't read the `write_db -common` format);
  - the VCD scope needs the `TOP/` prefix;
  - `report_power` writes with `-out`, not `-outfile`;
  - `rtlstim2gate` is enabled before `read_stimulus` (Joules' STIM-0551 advice).
