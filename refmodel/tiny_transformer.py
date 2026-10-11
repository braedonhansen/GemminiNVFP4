"""Toy transformer: d=4, 1 layer, 1 head, vocab 4. FP32 vs NVFP4 matmuls."""
import numpy as np
from quant import quantize, concat_rows
from hw_dot import hw_matmul

TOKENS = "ABCD"
D = 4


def softmax(x):
    e = np.exp(x - x.max(axis=-1, keepdims=True))
    return e / e.sum(axis=-1, keepdims=True)


def rms(x):
    return x / np.sqrt((x * x).mean(axis=-1, keepdims=True) + 1e-6)


class KVCache:
    def __init__(self, nvfp4):
        self.nvfp4 = nvfp4
        self.k, self.v, self.kq = [], [], []

    def append(self, k, v):
        for kr, vr in zip(k, v):
            self.k.append(kr)
            self.v.append(vr)
            if self.nvfp4:  # each cached K row is quantized once, with its own tensor scale
                self.kq.append(quantize(kr))

    def __len__(self):
        return len(self.k)

    def k_bytes_fp16(self):
        return len(self) * D * 2

    def k_bytes_nvfp4(self):
        """Packed 4-bit values plus one scale byte per row (tensor scales not counted)."""
        return sum(-(-q.k // 2) + q.scales.size for q in self.kq)


class ToyTransformer:
    def __init__(self, seed=0):
        rng = np.random.default_rng(seed)
        mat = lambda: rng.standard_normal((D, D)).astype(np.float32)
        self.E, self.P = mat(), rng.standard_normal((8, D)).astype(np.float32)
        # weights stored as (in, out); the LM head is tied to the embedding
        self.W = {n: mat() for n in ("Wq", "Wk", "Wv", "Wo", "W1", "W2")}
        self.W["head"] = self.E.T.copy()
        self.WQ = {n: quantize(w.T) for n, w in self.W.items()}  # blocks along input dim

    def lin(self, x, name, nvfp4):
        if not nvfp4:
            return x @ self.W[name]
        return hw_matmul(quantize(x), self.WQ[name]).astype(np.float32)

    def step(self, toks, start, cache, nvfp4):
        n = len(toks)
        pos = np.arange(start, start + n)
        h = self.E[toks] + self.P[pos]
        x = rms(h)
        q, k, v = (self.lin(x, w, nvfp4) for w in ("Wq", "Wk", "Wv"))
        cache.append(k, v)
        V = np.array(cache.v)
        if nvfp4:
            scores = hw_matmul(quantize(q), concat_rows(cache.kq)).astype(np.float32)
        else:
            scores = q @ np.array(cache.k).T
        scores = scores / np.sqrt(D)
        mask = np.arange(len(cache))[None, :] > pos[:, None]  # causal
        p = softmax(np.where(mask, -1e30, scores)).astype(np.float32)
        if nvfp4:  # reduction runs over tokens, so V is quantized transposed
            ctx = hw_matmul(quantize(p), quantize(V.T)).astype(np.float32)
        else:
            ctx = p @ V
        h = h + self.lin(ctx, "Wo", nvfp4)
        f = self.lin(np.maximum(self.lin(rms(h), "W1", nvfp4), 0), "W2", nvfp4)
        h = h + f
        return self.lin(rms(h), "head", nvfp4)[-1]

    def generate(self, prompt="AB", n_new=2, nvfp4=False):
        cache = KVCache(nvfp4)
        toks = [TOKENS.index(c) for c in prompt]
        logits = self.step(np.array(toks), 0, cache, nvfp4)
        out, probs = [], []
        for _ in range(n_new):
            p = softmax(logits)
            t = int(np.argmax(p))
            out.append(t)
            probs.append(p)
            logits = self.step(np.array([t]), len(cache), cache, nvfp4)
        return {"tokens": "".join(TOKENS[t] for t in out), "probs": probs, "cache": cache}


def report(seed=0):
    m = ToyTransformer(seed)
    res = {}
    for name, flag in (("FP32", False), ("NVFP4", True)):
        r = m.generate("AB", 2, flag)
        res[name] = r
        print(f"{name}: tokens {r['tokens']}")
        for i, p in enumerate(r["probs"]):
            print(f"  step {i + 1} probs " + " ".join(f"{c}={x:.3f}" for c, x in zip(TOKENS, p)))
    c = res["NVFP4"]["cache"]
    print(f"K cache ({len(c)} tokens): FP16 {c.k_bytes_fp16()} B, NVFP4 {c.k_bytes_nvfp4()} B")
    return res


def agreement_rate(n=200):
    same = 0
    for s in range(n):
        m = ToyTransformer(s)
        same += m.generate(nvfp4=False)["tokens"] == m.generate(nvfp4=True)["tokens"]
    return same / n


if __name__ == "__main__":
    report(0)
    print("token agreement over 200 seeds:", agreement_rate())
