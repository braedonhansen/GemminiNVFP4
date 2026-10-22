"""M7.A plots: SQNR (dB) vs K per input type, one line per format; Level H solid (dash-dot: MXFP4 with the OCP recipe), Level F dashed (MX formats: Level F with
the OCP recipe dashed, with the MX branch's recipe dotted). Reads docs/m7a/accuracy_summary.csv (accuracy_sweep.py --summarize).
  python refmodel/plot_m7a.py docs/m7a/accuracy_summary.csv docs/m7a
"""
import csv
import sys
from pathlib import Path
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt

DISTS = ["gaussian", "laplace", "student_t3", "outlier"]
COLORS = {"fp32": "#4d4d4d", "int8": "#c77d00", "mxfp8": "#1b7f3b", "mxfp4": "#b3261e", "nvfp4": "#1f4fd8"}
LABEL = {"fp32": "FP32", "int8": "INT8", "mxfp8": "MXFP8 E4M3", "mxfp4": "MXFP4", "nvfp4": "NVFP4"}
# (summary format name, family, line style, extra label) per level
LINES = [
    ("H", "fp32", "fp32", "-", ""), ("H", "int8", "int8", "-", ""), ("H", "mxfp8_branch", "mxfp8", "-", " branch recipe"),
    ("H", "mxfp4_branch", "mxfp4", "-", " branch recipe"), ("H", "mxfp4_ocp", "mxfp4", "-.", " OCP recipe"), ("H", "nvfp4", "nvfp4", "-", ""),
    ("F", "fp32", "fp32", "--", ""), ("F", "int8", "int8", "--", ""), ("F", "mxfp8_ocp", "mxfp8", "--", " F-OCP"),
    ("F", "mxfp4_ocp", "mxfp4", "--", " F-OCP"), ("F", "mxfp8_branch", "mxfp8", ":", " F-branch"),
    ("F", "mxfp4_branch", "mxfp4", ":", " F-branch"), ("F", "nvfp4", "nvfp4", "--", ""),
]


def load(path):
    d = {}
    with open(path) as f:
        for r in csv.DictReader(f):
            d[(r["level"], r["format"], r["input"], int(r["K"]))] = (float(r["sqnr_db"]), float(r["sqnr_db_ci95"]))
    return d


def draw(ax, d, dist, legend):
    ks = sorted({k[3] for k in d})
    for lvl, fmt, fam, ls, extra in LINES:
        ys = [d.get((lvl, fmt, dist, k)) for k in ks]
        if any(y is None for y in ys):
            continue
        m = [y[0] for y in ys]
        ci = [y[1] for y in ys]
        lw = 1.0 if ls == ":" else 1.8
        ax.plot(ks, m, ls, color=COLORS[fam], lw=lw, marker="o" if ls == "-" else None, ms=3.5,
                label=f"{LABEL[fam]}{extra} ({'H' if lvl == 'H' else 'F'})")
        ax.fill_between(ks, [a - b for a, b in zip(m, ci)], [a + b for a, b in zip(m, ci)], color=COLORS[fam], alpha=0.12, lw=0)
    ax.set_xscale("log", base=2)
    ax.set_xticks(ks)
    ax.set_xticklabels([str(k) for k in ks])
    ax.set_xlabel("K (reduction length)")
    ax.set_ylabel("SQNR (dB), higher is better")
    ax.set_title(dist.replace("_", " "))
    ax.grid(alpha=0.25)
    ax.set_ylim(0, 50)
    fp = [d.get(("H", "fp32", dist, k)) for k in ks]
    if all(x is not None for x in fp):
        ax.text(0.99, 0.97, f"FP32 is off scale: Level H {fp[-1][0]:.0f}-{fp[0][0]:.0f} dB (K 16384 to 16), Level F ~149 dB",
                transform=ax.transAxes, ha="right", va="top", fontsize=7, color=COLORS["fp32"])


def main(summary, outdir):
    d = load(summary)
    Path(outdir).mkdir(parents=True, exist_ok=True)
    for dist in DISTS:
        fig, ax = plt.subplots(figsize=(9.6, 4.6))
        draw(ax, d, dist, True)
        ax.legend(fontsize=7, ncol=1, loc="center left", bbox_to_anchor=(1.01, 0.5))
        fig.tight_layout()
        fig.savefig(Path(outdir) / f"sqnr_vs_k_{dist}.png", dpi=140)
        plt.close(fig)
    fig, axs = plt.subplots(2, 2, figsize=(13, 8.5), sharex=True)
    for ax, dist in zip(axs.ravel(), DISTS):
        draw(ax, d, dist, False)
    h, l = axs[0, 0].get_legend_handles_labels()
    fig.legend(h, l, fontsize=8, ncol=4, loc="lower center")
    fig.tight_layout(rect=(0, 0.07, 1, 1))
    fig.savefig(Path(outdir) / "sqnr_vs_k_all.png", dpi=130)
    plt.close(fig)
    print("wrote", len(DISTS) + 1, "plots to", outdir)


if __name__ == "__main__":
    main(sys.argv[1], sys.argv[2])
