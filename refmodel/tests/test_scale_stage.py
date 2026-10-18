import gzip
import numpy as np
import scale_stage as ss
from formats import e4m3_decode


def test_int_model_equals_float32_all_pairs_and_never_rounds():
    isums = ss.FIXED_ISUMS + [2303, -2303, 1155, -1155, 7, -2048]
    maxbits = 0
    for sa in range(256):
        for sb in range(256):
            sP, eS, _, _ = ss.stage0(sa, sb)
            assert sP < 256
            for i in isums:
                assert ss.scale_stage_int(i, sa, sb) == ss.scale_stage_f32(i, sa, sb), (i, sa, sb)
                if not (ss.is_nan_code(sa) or ss.is_nan_code(sb)):
                    maxbits = max(maxbits, (abs(i) * sP).bit_length())
                    # exact: the float64 product (53 bits) equals the float32 result, so nothing was rounded
                    v = float(i) * e4m3_decode(sa) * e4m3_decode(sb)
                    assert v == float(ss.bits_f32(ss.scale_stage_f32(i, sa, sb))), (i, sa, sb)
    assert maxbits <= 21


def test_exact_bound_by_construction():
    # |isum| <= 4096 (13-bit), sP <= 15*15 = 225 -> product < 2^20, within 21 bits <= 24-bit FP32 significand
    assert 4096 * 225 < (1 << 21) and 21 <= 24


def test_nan_and_sign_policy():
    assert ss.scale_stage_f32(5, 0x7F, 0x38) == ss.QNAN
    assert ss.scale_stage_f32(0, 0x38, 0xFF) == ss.QNAN
    assert ss.scale_stage_f32(0, 0x38, 0x38) == 0
    assert ss.scale_stage_f32(0, 0xB8, 0x38) == 0x80000000   # 0 * -1 = -0
    assert ss.scale_stage_f32(-3, 0x38, 0x38) == ss.f32_bits(-3.0)


def test_no_inf_or_subnormal_in_vectors():
    for s in ss.acc_vectors(n_seq=400):
        for _, _, _, c in s:
            e = (c >> 23) & 0xFF
            assert c == ss.QNAN or e == 0 and (c & 0x7FFFFF) == 0 or 0 < e < 255


def test_acc_sequence_matches_hw_matmul_v0_order():
    from quant import quantize
    from hw_dot import hw_matmul_v0
    rng = np.random.default_rng(3)
    qa = quantize(rng.standard_normal((4, 64)) * 3); qb = quantize(rng.standard_normal((5, 64)))
    sums, out = hw_matmul_v0(qa, qb)
    ts = (qa.tensor_scale[0] * qb.tensor_scale[0]) * np.float32(0.25)
    for m in range(4):
        for n in range(5):
            blocks = [(int(sums[m, n, k]), int(qa.scales[m, k]), int(qb.scales[n, k])) for k in range(4)]
            acc = ss.bits_f32(ss.acc_sequence(blocks)[-1])
            assert np.float32(acc * np.float32(ts)) == out[m, n]


def test_committed_vectors_current_and_sizes(tmp_path):
    rows, seqs = ss.export(tmp_path)
    assert len(rows) == 65536 * 6 + 100_000
    assert len({(a, b) for _, a, b, _ in rows[:65536 * 6]}) == 65536
    assert len(seqs) >= 10_000
    for name in ("scale_stage.txt.gz", "acc_seq.txt.gz"):
        assert gzip.open(tmp_path / name).read() == gzip.open(ss.OUT / name).read(), name
