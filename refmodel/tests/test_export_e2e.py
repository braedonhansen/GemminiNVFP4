"""M6.5: export_e2e.py regenerates the committed end-to-end headers byte-identically (default case + each seed/shape)."""
from pathlib import Path
import pytest
import export_e2e

HW = Path(__file__).resolve().parents[2] / "hw" / "tests"
CASES = [  # (header, seed, M, N, K)
    ("nvfp4_e2e_data.h", 20261018, 32, 32, 64),
    ("nvfp4_e2e_s2_data.h", 20261020, 32, 32, 64),
    ("nvfp4_e2e_s3_data.h", 20261021, 32, 32, 64),
    ("nvfp4_mt_m64n64k128_data.h", 20261101, 64, 64, 128),
    ("nvfp4_mt_m32n96k64_data.h", 20261102, 32, 96, 64),
    ("nvfp4_mt_m96n32k256_data.h", 20261103, 96, 32, 256),
    ("nvfp4_mt_m64n64k512_data.h", 20261104, 64, 64, 512),
]


@pytest.mark.parametrize("name,seed,m,n,k", CASES)
def test_header_regenerates_byte_identically(tmp_path, name, seed, m, n, k):
    committed = (HW / name).read_bytes()
    assert len(committed) > 1000, "committed header missing or empty"
    out = tmp_path / name
    export_e2e.export(out, seed, m, n, k)
    assert out.read_bytes() == committed


@pytest.mark.parametrize("name,seed,m,n,k", CASES[3:])
def test_multitile_cases_have_neg0_sensitive_outputs_in_every_tile(name, seed, m, n, k):
    import numpy as np
    from formats import e4m3_decode
    qa, qb, sums, out, *_ = export_e2e.build(seed, m, n, k)
    sa, sb = e4m3_decode(qa.scales).astype(np.float32), e4m3_decode(qb.scales).astype(np.float32)
    acc = None
    for kb in range(sums.shape[2]):
        blk = (sums[:, :, kb].astype(np.float32) * sa[:, None, kb]) * sb[None, :, kb]
        acc = blk if acc is None else (acc + blk).astype(np.float32)
    ts = (qa.tensor_scale[0] * qb.tensor_scale[0]) * np.float32(0.25)
    diff = (acc * np.float32(ts)).astype(np.float32).view(np.uint32) != out.view(np.uint32)
    for t in range(m // 32):
        for u in range(n // 32):
            assert diff[32 * t:32 * t + 32, 32 * u:32 * u + 32].sum() >= 1, (t, u)
