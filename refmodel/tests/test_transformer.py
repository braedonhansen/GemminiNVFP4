import numpy as np
from tiny_transformer import ToyTransformer, agreement_rate


def test_tokens_agree_fp32_vs_nvfp4():
    m = ToyTransformer(0)
    assert m.generate(nvfp4=False)["tokens"] == m.generate(nvfp4=True)["tokens"]


def test_probabilities_normalized_and_close():
    m = ToyTransformer(0)
    f, q = m.generate(nvfp4=False), m.generate(nvfp4=True)
    for pf, pq in zip(f["probs"], q["probs"]):
        assert abs(pf.sum() - 1) < 1e-5 and abs(pq.sum() - 1) < 1e-5
        assert np.abs(pf - pq).max() < 0.15


def test_deterministic():
    a = ToyTransformer(0).generate(nvfp4=True)
    b = ToyTransformer(0).generate(nvfp4=True)
    assert a["tokens"] == b["tokens"]
    assert all(np.array_equal(x, y) for x, y in zip(a["probs"], b["probs"]))


def test_k_cache_bytes():
    c = ToyTransformer(0).generate(nvfp4=True)["cache"]
    assert len(c) == 4
    assert c.k_bytes_fp16() == 32 and c.k_bytes_nvfp4() == 12


def test_agreement_rate_reasonable():
    assert agreement_rate(40) >= 0.6
