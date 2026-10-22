"""M7.A / A5: the d=4 toy transformer of refmodel/tiny_transformer.py run with each format's matmul.

The model is the same one (1 layer, 1 head, d = 4, vocab 4, tied head, rms norm, ReLU MLP, same weight init per seed),
rewritten as a single teacher-forced forward pass over a random token sequence so every position yields logits.
Every matmul (Wq, Wk, Wv, Q K^T, P V, Wo, W1, W2, head) goes through one `mm(a, b)` function: the reference uses float64;
a format uses its Level-F or Level-H matmul from hw_models with BOTH operands quantized fresh for that call
(per-call per-tensor scales; the KV cache is not quantized incrementally the way tiny_transformer.KVCache does it).
Non-matmul operations (rms norm, softmax, ReLU, residual adds) stay float64 for every format.

This is a toy: reduction lengths are 4 (projections) and <= 8 (attention), far shorter than a real model's, so block
formats see zero-padded blocks. It checks plumbing and ordering, not real-model behaviour.
"""
import csv
import math
import sys
from pathlib import Path
import numpy as np
import hw_models as hm

D = 4
VOCAB = 4
T = 8                  # sequence length (the toy has 8 learned positions)


def softmax(x):
    e = np.exp(x - x.max(axis=-1, keepdims=True))
    return e / e.sum(axis=-1, keepdims=True)


def log_softmax(x):
    x = x - x.max(axis=-1, keepdims=True)
    return x - np.log(np.exp(x).sum(axis=-1, keepdims=True))


def rms(x):
    return x / np.sqrt((x * x).mean(axis=-1, keepdims=True) + 1e-6)


def weights(seed):
    """Same initialisation order as tiny_transformer.ToyTransformer, in float64."""
    rng = np.random.default_rng(seed)
    mat = lambda: rng.standard_normal((D, D)).astype(np.float32).astype(np.float64)
    E = mat()
    P = rng.standard_normal((8, D)).astype(np.float32).astype(np.float64)
    W = {n: mat() for n in ("Wq", "Wk", "Wv", "Wo", "W1", "W2")}
    W["head"] = E.T.copy()
    return E, P, W


def forward(tokens, E, P, W, mm):
    n = len(tokens)
    h = E[tokens] + P[:n]
    x = rms(h)
    q, k, v = mm(x, W["Wq"]), mm(x, W["Wk"]), mm(x, W["Wv"])
    scores = mm(q, k.T) / math.sqrt(D)
    scores = np.where(np.arange(n)[None, :] > np.arange(n)[:, None], -1e30, scores)
    p = softmax(scores)
    ctx = mm(p, v)
    h = h + mm(ctx, W["Wo"])
    f = mm(np.maximum(mm(rms(h), W["W1"]), 0), W["W2"])
    h = h + f
    return mm(rms(h), W["head"])


def ref_mm(a, b):
    return np.asarray(a, np.float64) @ np.asarray(b, np.float64)


def padded(fn, mult=16):
    """Level-H models work on whole 16-wide reduction tiles: zero-pad K (exact for every format here)."""
    def mm(a, b):
        a, b = np.asarray(a, np.float64), np.asarray(b, np.float64)
        k = a.shape[1]
        kp = -(-k // mult) * mult
        if kp != k:
            a = np.pad(a, ((0, 0), (0, kp - k)))
            b = np.pad(b, ((0, kp - k), (0, 0)))
        return np.asarray(fn(a, b), np.float64)
    return mm


def kl_rows(ref_logits, logits):
    lp, lq = log_softmax(ref_logits), log_softmax(logits)
    return (np.exp(lp) * (lp - lq)).sum(axis=-1)


def run(n_models=200, seqs_per_model=4, out_path=None):
    rows = []
    entries = [("F", name, fn) for name, fn in hm.LEVEL_F.items()] + \
              [("H", name, fn) for name, fn in hm.LEVEL_H.items() if name not in ("mxfp8_ocp", "mxfp4_ocp")]
    stats = {(lvl, name): dict(kl=[], agree=[], sq=[], nonfinite=0) for lvl, name, _ in entries}
    total_rows = 0
    for s in range(n_models):
        E, P, W = weights(s)
        rng = np.random.default_rng([s, 4242])
        for _ in range(seqs_per_model):
            toks = rng.integers(0, VOCAB, T)
            ref = forward(toks, E, P, W, ref_mm)
            total_rows += len(toks)
            for lvl, name, fn in entries:
                out = forward(toks, E, P, W, padded(fn))
                st = stats[(lvl, name)]
                if not np.isfinite(out).all():
                    st["nonfinite"] += 1
                    continue
                st["kl"].append(float(kl_rows(ref, out).mean()))
                st["agree"].append(float((out.argmax(-1) == ref.argmax(-1)).mean()))
                st["sq"].append(10 * math.log10((ref ** 2).sum() / max(((out - ref) ** 2).sum(), 1e-300)))
    assert total_rows > 0
    for (lvl, name), st in stats.items():
        n = len(st["kl"])
        assert n > 0, f"{lvl} {name}: no finite sequences"
        kl, ag, sq = np.array(st["kl"]), np.array(st["agree"]), np.array(st["sq"])
        ci = lambda v: 1.96 * v.std(ddof=1) / math.sqrt(len(v))
        rows.append(dict(level=lvl, format=name, n_sequences=n, n_positions=n * T, n_nonfinite_sequences=st["nonfinite"],
                         mean_kl=kl.mean(), kl_ci95=ci(kl), top1_agreement=ag.mean(), top1_ci95=ci(ag),
                         logit_sqnr_db=sq.mean(), sqnr_ci95=ci(sq)))
    if out_path:
        Path(out_path).parent.mkdir(parents=True, exist_ok=True)
        with open(out_path, "w", newline="") as f:
            w = csv.DictWriter(f, fieldnames=list(rows[0]))
            w.writeheader()
            w.writerows(rows)
    return rows, total_rows


if __name__ == "__main__":
    out = sys.argv[1] if len(sys.argv) > 1 else "docs/m7a/transformer.csv"
    nm = int(sys.argv[2]) if len(sys.argv) > 2 else 200
    rows, total = run(nm, 4, out)
    print(f"{nm} models x 4 sequences x {T} positions = {total} reference logit rows; wrote {out} ({len(rows)} rows)")
    print(f"{'lvl':3s} {'format':24s} {'seqs':>5s} {'KL':>11s} {'top1':>7s} {'logit SQNR dB':>14s}")
    for r in rows:
        print(f"{r['level']:3s} {r['format']:24s} {r['n_sequences']:5d} {r['mean_kl']:11.3e} {r['top1_agreement']:7.4f} {r['logit_sqnr_db']:14.2f}"
              + (f"   ({r['n_nonfinite_sequences']} non-finite sequences dropped)" if r['n_nonfinite_sequences'] else ""))
