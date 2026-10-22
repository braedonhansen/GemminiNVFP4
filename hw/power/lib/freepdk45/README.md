# FreePDK45 library kit for Genus/Joules (M7.P0b)

Ready to ship in a job tarball. Full write-up: `docs/M7.P0b-libraries.md`. Total size 7.3 MB, no file over 20 MB.

## Layout
| Path | What |
|---|---|
| `nangate45/` | Nangate Open Cell Library typical-corner `.lib`, tech + macro `.lef`, licences |
| `openram/banks/` | five OpenRAM bank macros: `<bank>.lib` (raw, as generated), `<bank>_pj.lib` (**use this one**: energy in pJ, disabled states 0), `<bank>.v` (simulation model only) |
| `openram/configs/` | the OpenRAM config file used for each bank |
| `openram/logs/` | OpenRAM run logs and `time -v` (run time, peak memory) |
| `openram/python-deps-freeze.txt` | Python packages of the OpenRAM venv |
| `wrappers/<design>/` | `mem_ext.v` etc.: Chipyard-compatible SRAM modules built from the banks (`int8`, `mxfp4`, `nvfp4` elaborated; `mxfp8`, `fp32` derived) |
| `macros.json` | SRAM inventory and compositions |
| `energy_table.md` | per-bank and per-macro energy and leakage |
| `verify/` | check logs: lib check, port diff, wrapper simulation |
| `PROVENANCE.txt`, `MANIFEST.sha256` | sources, commits, file hashes |
| `../tools/` | generators and checkers (`gen_wrappers.py`, `fix_lib_power.py`, `check_macro_libs.py`, `port_diff.py`, `energy_table.py`, `tb/`) |

## Provenance
- Nangate45: `https://github.com/The-OpenROAD-Project/OpenROAD-flow-scripts`, sparse checkout of `flow/platforms/nangate45`, commit
  `0b56643596e8ffd41b929858107c36602e0644f5`. Licences: `nangate45/LICENSE.nangate45-platform-Apache2`, `LICENSE_BUILD_RUN_SCRIPTS`; the `.lib` has its own Nangate header.
- OpenRAM: `https://github.com/VLSIDA/OpenRAM`, tag `v1.2.48`, commit `b6a6f12642df6b84facc24a77f9a6f67a0d62dab`. Licence: `openram/LICENSE.openram`.
- OpenRAM settings (every bank): `tech_name = "freepdk45"`, `netlist_only = True`, `analytical_delay = True`, `nominal_corner_only = True`, `use_conda = False`. Per-bank configs in `openram/configs/`.
- Python deps from PyPI (numpy, scipy, scikit-learn, coverage) in a venv under `~/nvfp4-logs/m7p-lib/venv`.
- The clones were made with Windows git and the wheels with Windows pip, because WSL has no outbound network in this session.

## Use
Load `nangate45/NangateOpenCellLibrary_typical.lib` and the `openram/banks/*_pj.lib` files; read the design RTL plus **one** `wrappers/<design>/` folder; do not read `openram/banks/*.v`
or Chipyard's `*.top.mems.v`. Details in section 5 of the doc.

## Known limits (short)
Analytical model, typical corner, no layout; leakage is OpenRAM's 1 nW/bit placeholder; read and write energy are equal; macro area is 0; the `_pj` libs correct a units problem in
OpenRAM's raw numbers (see the doc, section 4). The kit has not yet been read by Genus.
