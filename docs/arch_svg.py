"""Static SVG of the NVFP4-on-MX-Gemmini architecture diagram, for the portfolio page.

Same geometry as the report's diagram; light-theme colors matched to the page.
"""
import os
from html import escape

NEW, ED, EX = '#0a58ca', '#d9480f', '#2b8a3e'
FILL = {'new': '#e7f0fd', 'ed': '#fdece4', 'ex': '#e8f4ea'}
COL = {'new': NEW, 'ed': ED, 'ex': EX}
INK, QUIET, EDGE = '#24292f', '#57606a', '#8c959f'
DY = -48  # no title/subtitle on the page (the figure caption carries them)

o = []


def y(v):
    return v + DY


def text(x, yy, s, size=11.5, weight=None, fill=INK):
    fw = f' font-weight="{weight}"' if weight else ''
    o.append(f'<text x="{x}" y="{y(yy)}" font-size="{size}"{fw} fill="{fill}">{escape(s, quote=False)}</text>')


def block(x, yy, w, h, k, name, lines, dash=False):
    d = ' stroke-dasharray="6 4"' if dash else ''
    o.append(f'<rect x="{x}" y="{y(yy)}" width="{w}" height="{h}" rx="8" fill="{FILL[k]}" stroke="{COL[k]}" stroke-width="2"{d}/>')
    text(x + 16, yy + 24, name, 13, 600)
    for i, (s, quiet) in enumerate(lines):
        text(x + 16, yy + 40 + 16 * i, s, fill=QUIET if quiet else INK)


def path(points, dash=False):
    """points: list of (x, y) in diagram coordinates; draws an orthogonal polyline."""
    d = 'M' + ' L'.join(f'{px} {y(py)}' for px, py in points)
    extra = ' stroke-dasharray="4 4"' if dash else ' marker-end="url(#nvfp4-arch-arrow)"'
    o.append(f'<path d="{d}" fill="none" stroke="{EDGE}" stroke-width="1.25"{extra}/>')


H = 1240 + DY
o.append(f'<svg viewBox="0 0 760 {H}" role="img" aria-label="NVFP4 datapath inside MX Gemmini: new blocks do the math, edited blocks route it" '
         'xmlns="http://www.w3.org/2000/svg" style="width:100%;height:auto;font-family:inherit">')
o.append(f'<defs><marker id="nvfp4-arch-arrow" viewBox="0 0 10 10" refX="9" refY="5" markerWidth="6" markerHeight="6" '
         f'orient="auto-start-reverse"><path d="M0 0L10 5L0 10z" fill="{EDGE}"/></marker></defs>')

# key
for x, k, label in [(24, 'new', 'new for NVFP4'), (164, 'ed', 'edited MX Gemmini block'),
                    (350, 'ex', 'existing MX Gemmini / MxGen block, unchanged')]:
    o.append(f'<rect x="{x}" y="{y(68)}" width="14" height="14" rx="3" fill="{FILL[k]}" stroke="{COL[k]}" stroke-width="2"/>')
    text(x + 22, 79, label)

# connectors
for pts in [[(260, 192), (260, 214)], [(260, 304), (260, 326)], [(260, 416), (260, 438)],
            [(260, 544), (260, 566)], [(470, 704), (470, 798)], [(260, 888), (260, 902)],
            [(138, 992), (138, 1030)], [(252, 1068), (266, 1068)], [(382, 1104), (382, 1126)],
            [(496, 148), (628, 148), (628, 214)], [(520, 304), (508, 304), (508, 844), (482, 844)]]:
    path(pts)
path([(520, 612), (498, 612)], dash=True)
text(512, 140, 'MX_LOAD_SCALES', fill=QUIET)
text(520, 344, 'raw E4M3 sA, sB bytes,', fill=QUIET)
text(520, 360, 'one set per pass, to the', fill=QUIET)
text(520, 376, 'scale stage', fill=QUIET)

block(24, 104, 472, 88, 'ex', 'Software and DRAM (RISC-V core)', [
    ('A, B: E2M1 codes, 2 per byte (pairs along M for A, N for B)', 0),
    ('E4M3 block scales: sA[K/16][M], sB[K/16][N]', 0),
    ('tensor factor (tA x tB) x 0.25f, set once via config_mvout', 0)])
block(24, 216, 472, 88, 'ed', 'Command path: RoCC, reservation station, LoopMatmul', [
    ('loop_ws walks the i, j, k tiles; one pass = one 16-element K block', 0),
    ('scale_size replaces the hardcoded 32, so tilesPerMxBlock = 1', 0),
    ('FP32 store addressing doubled for 4-byte lanes', 0)])
block(520, 216, 216, 104, 'ed', 'ScaleFactorMem', [
    ('MX_LOAD_SCALES fills banks', 0), ('E4M3, 1 per 16 values', 0),
    ('(MX: E8M0, 1 per 32)', 1), ('returns raw sA, sB bytes', 0)])
block(24, 328, 472, 88, 'ed', 'Scratchpad', [
    ('E2M1 values via mvin DMA, 2 per byte, 16 bytes per row', 0),
    ('NVFP4 flag passed through to AccumulatorScale', 0),
    ('mvout reads wait while the delayed accumulate read owns the port', 0)])
block(24, 440, 472, 104, 'ed', 'ExecuteController and MeshWithDelays', [
    ('feeds 16 activation rows and preloads 16 weight rows per pass', 0),
    ('skew and de-skew unchanged', 1),
    ('mesh picked at build: use_nvfp4 ? NvFp4MeshAdapter : MX Mesh', 0),
    ('packs 4 int16 lane sums into the low 64 bits of each acc write', 0)])
block(24, 568, 472, 136, 'new', 'NvFp4Mesh: 16 x 16 NvFp4PE', [
    ('per PE: 2 activations x 2 weights = 4 lanes; each operand decoded once', 0),
    ("decode: code to sign, m' = 1 or 3, k = 0 to 3, zero flag", 0),
    ('product = 1, 3 or 9, shifted left by ka + kb (magnitude at most 144)', 0),
    ('column add: c + (s ? ~mag : mag) + s, exact 13-bit sum up to 2304', 0),
    ('weights double-buffered (c1/c2, flip on propagate); L+1 regs per hop', 0),
    ('NvFp4MeshAdapter gives it the same ports as the MX Mesh', 1)])
block(520, 568, 216, 88, 'ex', 'MxGen MxFpMul PE', [
    ('FP4/6/8 float MAC, BF16 ramp', 0), ('used by MX configs only', 0),
    ('replaced by NvFp4Mesh here', 1)], dash=True)
block(24, 728, 472, 280, 'ed', 'AccumulatorMem', [
    ('4 x IEEE FP32 per 128-bit row (MX: BF16)', 0),
    ("replaces MX's exponent-add scaling (applyE9M0Scale)", 0)])
block(40, 800, 440, 88, 'new', 'NvFp4ScaleStage, 3 cycles', [
    ('S0: sA x sB, multiply 4-bit significands, add exponents', 0),
    ('S1: times the 13-bit lane sum, at most 21 bits', 0),
    ('S2: normalize and pack to FP32, exact (21 of 24 bits)', 0)])
block(40, 904, 440, 88, 'new', 'NvFp4RmwPipe with Fp32AccAdd2, 3 cycles', [
    ('read the old row; first write is +0 + block, as in IEEE', 0),
    ('2-stage hardfloat FP32 add, round to nearest even', 0),
    ('same-row write inside the pipeline stalls (acc_latency = 6)', 0)])
block(24, 1032, 228, 72, 'ed', 'AccumulatorScale', [
    ('NVFP4 branch scales all lanes', 0), ('factor rides the DMA read', 0)])
block(268, 1032, 228, 72, 'new', 'Fp32Mul2', [
    ('x tensor factor, FP32, RNE', 0), ('2 pipeline stages', 0)])
block(24, 1128, 472, 88, 'ex', 'Store to DRAM', [
    ('FP32 rows to scratchpad (4 per row, 8 beats per chunk), then mvout', 0),
    ('existing DMA path; addressing comes from LoopMatmul (edited)', 0),
    ('deferred: direct accumulator-to-DRAM FP32 store', 1)])
o.append('</svg>')

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'arch.svg')
open(out, 'w', encoding='utf-8').write('\n'.join(o) + '\n')
print('wrote', out)
