"""M7.A accuracy sweep: FP32, INT8, MXFP8 (E4M3), MXFP4, NVFP4 against an FP64 matmul of the unquantized inputs.

  python refmodel/accuracy_sweep.py --level F --out docs/m7a/accuracy_F.csv
  python refmodel/accuracy_sweep.py --level H --out docs/m7a/accuracy_H.csv
  python refmodel/accuracy_sweep.py --summarize docs/m7a/accuracy_F.csv docs/m7a/accuracy_H.csv

Grid: inputs {gaussian, laplace, student_t3, outlier} x K {16, 64, 256, 1024, 4096, 16384} x 10 seeds, M = N = 64.
Metrics (per cell): SQNR dB, relative Frobenius error, max abs error, max rel error (outputs with |ref| > 1e-3 max|ref|),
cosine similarity. Exits nonzero if any cell compared 0 elements or the row count is not formats x inputs x K x seeds.
"""
import argparse
import csv
import math
import sys
import time
from concurrent.futures import ProcessPoolExecutor
from pathlib import Path
import numpy as np

DISTS = ["gaussian", "laplace", "student_t3", "outlier"]
KS = [16, 64, 256, 1024, 4096, 16384]
SEEDS = list(range(10))
M = N = 64
OUTLIER_SCALE = 100.0
OUTLIER_EVERY = 64          # outlier channels: one K-column of A per 64 (at least one), scaled x100
COLUMNS = ["level", "format", "input", "K", "seed", "M", "N", "n_compared", "n_nonfinite", "sqnr_db", "rel_fro",
           "max_abs", "max_rel", "cosine"]


def make_inputs(dist, K, seed, m=M, n=N):
    """A (m, K), B (K, n) float64. The generator is seeded by (seed, K, dist) so every cell is reproducible."""
    rng = np.random.default_rng([seed, K, DISTS.index(dist)])
    if dist == "gaussian":
        draw = rng.standard_normal
    elif dist == "laplace":
        draw = lambda size: rng.laplace(0.0, 1.0, size)
    elif dist == "student_t3":
        draw = lambda size: rng.standard_t(3, size)
    elif dist == "outlier":
        draw = rng.standard_normal
    else:
        raise ValueError(dist)
    a, b = draw((m, K)), draw((K, n))
    if dist == "outlier":
        cols = rng.choice(K, size=max(1, K // OUTLIER_EVERY), replace=False)
        a[:, cols] *= OUTLIER_SCALE
    return a, b


def metrics(out, ref):
    out, ref = np.asarray(out, np.float64), np.asarray(ref, np.float64)
    if out.shape != ref.shape:
        raise ValueError("shape mismatch")
    n = ref.size
    if n == 0:
        raise ValueError("compared 0 elements")
    nonfinite = int((~np.isfinite(out)).sum())
    if nonfinite:
        return dict(n_compared=n, n_nonfinite=nonfinite, sqnr_db=math.nan, rel_fro=math.nan, max_abs=math.nan,
                    max_rel=math.nan, cosine=math.nan)
    err = out - ref
    se, sr = float((err ** 2).sum()), float((ref ** 2).sum())
    if sr == 0:
        raise ValueError("reference is identically zero")
    mask = np.abs(ref) > 1e-3 * np.abs(ref).max()
    assert mask.any()
    on, rn = np.linalg.norm(out), np.linalg.norm(ref)
    return dict(
        n_compared=n, n_nonfinite=0,
        sqnr_db=math.inf if se == 0 else 10 * math.log10(sr / se),
        rel_fro=math.sqrt(se / sr),
        max_abs=float(np.abs(err).max()),
        max_rel=float((np.abs(err[mask]) / np.abs(ref[mask])).max()),
        cosine=float((out * ref).sum() / (on * rn)) if on > 0 else 0.0,
    )


def _table(level):
    import hw_models as hm
    return hm.LEVEL_F if level == "F" else hm.LEVEL_H


def _cell(args):
    """One (dist, K, seed) cell: every format on the same inputs. Runs in a worker process."""
    level, dist, K, seed, formats = args
    table = _table(level)
    a, b = make_inputs(dist, K, seed)
    ref = a @ b
    rows = []
    for name in formats:
        t0 = time.time()
        out = table[name](a, b)
        mt = metrics(out, ref)
        rows.append(dict(level=level, format=name, input=dist, K=K, seed=seed, M=M, N=N, **mt))
        rows[-1]["_sec"] = time.time() - t0
    return rows


def control():
    """No-quantization path: error exactly 0, SQNR inf, and the metric must refuse to compare nothing."""
    a, b = make_inputs("gaussian", 64, 0)
    m = metrics(a @ b, a @ b)
    assert m["n_compared"] == M * N and m["max_abs"] == 0.0 and m["rel_fro"] == 0.0 and math.isinf(m["sqnr_db"]) and abs(m["cosine"] - 1.0) < 1e-12, m
    try:
        metrics(np.zeros((0, 0)), np.zeros((0, 0)))
    except ValueError:
        pass
    else:
        raise AssertionError("metrics accepted an empty comparison")
    # a deliberately perturbed output must NOT look perfect
    bad = metrics(a @ b + 1e-6, a @ b)
    assert bad["max_abs"] > 0 and math.isfinite(bad["sqnr_db"])
    print(f"control PASS: no-quantization n_compared={m['n_compared']} max_abs={m['max_abs']} sqnr={m['sqnr_db']}; perturbed sqnr={bad['sqnr_db']:.1f} dB")


def run(level, out_path, workers, formats=None, ks=KS, seeds=SEEDS, dists=DISTS):
    table = _table(level)
    formats = formats or list(table)
    control()
    tasks = [(level, d, K, s, formats) for K in ks for d in dists for s in seeds]
    rows = []
    t0 = time.time()
    with ProcessPoolExecutor(max_workers=workers) as ex:
        for i, r in enumerate(ex.map(_cell, tasks, chunksize=1)):
            rows.extend(r)
            if (i + 1) % 20 == 0 or i + 1 == len(tasks):
                print(f"  {i + 1}/{len(tasks)} cells, {len(rows)} rows, {time.time() - t0:.0f} s", flush=True)
    for r in rows:
        r.pop("_sec", None)
    expected = len(formats) * len(dists) * len(ks) * len(seeds)
    bad = [r for r in rows if r["n_compared"] <= 0]
    order = {f: i for i, f in enumerate(formats)}
    rows.sort(key=lambda r: (order[r["format"]], DISTS.index(r["input"]), r["K"], r["seed"]))
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    with open(out_path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=COLUMNS)
        w.writeheader()
        w.writerows(rows)
    print(f"wrote {out_path}: {len(rows)} rows (expected {expected} = {len(formats)} formats x {len(dists)} inputs x {len(ks)} K x {len(seeds)} seeds); "
          f"{len(bad)} cells with 0 compared; non-finite outputs in {sum(1 for r in rows if r['n_nonfinite'])} rows")
    if len(rows) != expected or bad or not rows:
        sys.exit(2)
    return rows


T975 = {9: 2.262157}   # two-sided 95% Student-t quantile for n - 1 = 9 degrees of freedom


def summarize(paths, out_path):
    """Mean and 95% CI (t, n-1 dof) over seeds for every (level, format, input, K); prints and writes a CSV."""
    out = []
    for p in paths:
        with open(p) as f:
            rd = list(csv.DictReader(f))
        assert rd, f"{p} is empty"
        groups = {}
        for r in rd:
            groups.setdefault((r["level"], r["format"], r["input"], int(r["K"])), []).append(r)
        for key, rs in groups.items():
            n = len(rs)
            rec = dict(level=key[0], format=key[1], input=key[2], K=key[3], n_seeds=n,
                       n_nonfinite_rows=sum(1 for r in rs if int(r["n_nonfinite"]) > 0))
            for met in ("sqnr_db", "rel_fro", "max_abs", "max_rel", "cosine"):
                v = np.array([float(r[met]) for r in rs])
                v = v[np.isfinite(v)]
                if len(v) == 0:
                    rec[met], rec[met + "_ci95"] = math.nan, math.nan
                    continue
                mean = float(v.mean())
                sd = float(v.std(ddof=1)) if len(v) > 1 else math.nan
                tq = T975.get(len(v) - 1, 1.96)
                rec[met] = mean
                rec[met + "_ci95"] = tq * sd / math.sqrt(len(v)) if len(v) > 1 else math.nan
            out.append(rec)
    Path(out_path).parent.mkdir(parents=True, exist_ok=True)
    cols = list(out[0].keys())
    with open(out_path, "w", newline="") as f:
        w = csv.DictWriter(f, fieldnames=cols)
        w.writeheader()
        w.writerows(out)
    print(f"wrote {out_path}: {len(out)} summary rows")
    return out


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--level", choices=["F", "H"])
    ap.add_argument("--out")
    ap.add_argument("--workers", type=int, default=8)
    ap.add_argument("--formats", nargs="*")
    ap.add_argument("--ks", nargs="*", type=int)
    ap.add_argument("--seeds", type=int, default=len(SEEDS))
    ap.add_argument("--summarize", nargs="*")
    ap.add_argument("--summary-out", default="docs/m7a/accuracy_summary.csv")
    a = ap.parse_args()
    if a.summarize:
        summarize(a.summarize, a.summary_out)
    else:
        run(a.level, a.out, a.workers, a.formats, a.ks or KS, list(range(a.seeds)))
