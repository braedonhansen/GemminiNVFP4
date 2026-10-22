"""Markdown tables for docs/M7-accuracy-results.md, generated from the CSVs in docs/m7a (so every number traces to a CSV).
  python refmodel/m7a_tables.py k1024 | ablation | longk | transformer | counts
"""
import csv
import sys
from collections import defaultdict

D = "docs/m7a/"
DISTS = ["gaussian", "laplace", "student_t3", "outlier"]


def summary():
    s = {}
    for r in csv.DictReader(open(D + "accuracy_summary.csv")):
        s[(r["level"], r["format"], r["input"], int(r["K"]))] = r
    return s


def cell(r, m="sqnr_db", p=1):
    return f"{float(r[m]):.{p}f} +/- {float(r[m + '_ci95']):.{p}f}"


def table(rows, K, metric="sqnr_db", p=1):
    s = summary()
    out = ["| level | format | " + " | ".join(DISTS) + " |", "|---|---|" + "---|" * len(DISTS)]
    for lvl, fmt, label in rows:
        cells = []
        for d in DISTS:
            r = s.get((lvl, fmt, d, K))
            if r is None:
                cells.append("n/a")
            elif int(r["n_nonfinite_rows"]) == int(r["n_seeds"]):
                cells.append("inf/NaN (all seeds)")
            else:
                cells.append(cell(r, metric, p))
        out.append(f"| {lvl} | {label} | " + " | ".join(cells) + " |")
    return "\n".join(out)


MAIN = [("H", "fp32", "FP32 (stock, DIM 4)"), ("F", "fp32", "FP32"), ("H", "int8", "INT8 (stock)"), ("F", "int8", "INT8"),
        ("H", "mxfp8_branch", "MXFP8 E4M3, branch recipe"), ("F", "mxfp8_branch", "MXFP8 E4M3, branch recipe"), ("F", "mxfp8_ocp", "MXFP8 E4M3, OCP recipe"), ("H", "mxfp8_ocp", "MXFP8 E4M3, OCP recipe"),
        ("H", "mxfp4_branch", "MXFP4, branch recipe"), ("F", "mxfp4_branch", "MXFP4, branch recipe"), ("F", "mxfp4_ocp", "MXFP4, OCP recipe"), ("H", "mxfp4_ocp", "MXFP4, OCP recipe"),
        ("H", "nvfp4", "NVFP4"), ("F", "nvfp4", "NVFP4")]
ABL = [("H", "nvfp4", "NVFP4 (FP32 accumulator, hardware)"), ("H", "nvfp4_bf16acc", "NVFP4 with BF16 accumulator [software]"),
       ("H", "mxfp4_branch", "MXFP4 branch (BF16 + ramp, hardware)"), ("H", "mxfp4_branch_fp32acc", "MXFP4 branch with FP32 accumulator [software]"),
       ("H", "fp32", "FP32, separate mul+add (Spike-verified)"), ("H", "fp32_fused", "FP32, fused MAC (Arithmetic.scala; RTL-unverified)")]

def gapfrac(K=1024):
    """Fraction of the (MXFP4 -> MXFP8) SQNR gap that NVFP4 covers: (nvfp4 - mxfp4) / (mxfp8 - mxfp4), three ways to pick the MX baselines."""
    s = summary()
    q = lambda l, f, d: float(s[(l, f, d, K)]["sqnr_db"])
    out = ["| input | Level H, MX branch recipe (MXFP4 and MXFP8) | Level H, MXFP4 with OCP recipe, MXFP8 branch | Level F, both OCP recipe |", "|---|---|---|---|"]
    for d in DISTS:
        nvh, nvf = q("H", "nvfp4", d), q("F", "nvfp4", d)
        a = (nvh - q("H", "mxfp4_branch", d)) / (q("H", "mxfp8_branch", d) - q("H", "mxfp4_branch", d))
        b = (nvh - q("H", "mxfp4_ocp", d)) / (q("H", "mxfp8_branch", d) - q("H", "mxfp4_ocp", d))
        c = (nvf - q("F", "mxfp4_ocp", d)) / (q("F", "mxfp8_ocp", d) - q("F", "mxfp4_ocp", d))
        out.append(f"| {d} | {a:.2f} | {b:.2f} | {c:.2f} |")
    return "\n".join(out)


if __name__ == "__main__":
    what = sys.argv[1]
    if what == "k1024":
        print(table(MAIN, 1024))
    elif what == "k1024_relfro":
        print(table(MAIN, 1024, "rel_fro", 4))
    elif what == "ablation":
        for K in (1024, 16384):
            print(f"\nK = {K}\n")
            print(table(ABL, K))
    elif what == "gapfrac":
        print(gapfrac())
    elif what == "longk":
        for K in (16, 64, 256, 4096, 16384):
            print(f"\nK = {K}\n")
            print(table(MAIN, K))
    elif what == "transformer":
        rows = list(csv.DictReader(open(D + "transformer.csv")))
        print("| level | format | sequences | mean logit KL +/- 95% CI | top-1 agreement | logit SQNR dB |\n|---|---|---|---|---|---|")
        for r in rows:
            print(f"| {r['level']} | {r['format']} | {r['n_sequences']} | {float(r['mean_kl']):.3e} +/- {float(r['kl_ci95']):.1e} | {float(r['top1_agreement']):.4f} +/- {float(r['top1_ci95']):.4f} | {float(r['logit_sqnr_db']):.2f} +/- {float(r['sqnr_ci95']):.2f} |")
    elif what == "counts":
        for f in ("accuracy_F.csv", "accuracy_H.csv"):
            rows = list(csv.DictReader(open(D + f)))
            fmts = sorted({r["format"] for r in rows})
            print(f, len(rows), "rows;", len(fmts), "formats", fmts)
