import re
import numpy as np
import pytest
from formats import e4m3_decode
from hw_dot import hw_matmul, hw_matmul_v0, block_sums
from export_c import make_case, case_arrays, export_c_header, f32_bits, CASES, M, N


@pytest.mark.parametrize("name,k,seed", CASES)
def test_sums_match_block_sums(name, k, seed):
    qa, qb = make_case(k, seed)
    sums, out = hw_matmul_v0(qa, qb)
    assert sums.dtype == np.int32 and out.dtype == np.float32
    assert sums.shape == (M, N, k // 16)
    assert (sums == block_sums(qa, qb)).all()


@pytest.mark.parametrize("name,k,seed", CASES)
def test_close_to_float64_hw_matmul(name, k, seed):
    qa, qb = make_case(k, seed)
    _, out = hw_matmul_v0(qa, qb)
    ref = hw_matmul(qa, qb)
    assert np.allclose(out, ref, rtol=1e-5, atol=0)


@pytest.mark.parametrize("name,k,seed", CASES)
def test_scalar_float32_loop_matches(name, k, seed):
    """An element-by-element float32 loop (what the C code does) gives identical bits."""
    f = np.float32
    qa, qb = make_case(k, seed)
    sums, out = hw_matmul_v0(qa, qb)
    sa, sb = e4m3_decode(qa.scales).astype(f), e4m3_decode(qb.scales).astype(f)
    ts = f(f(qa.tensor_scale[0] * qb.tensor_scale[0]) * f(0.25))
    for i in range(M):
        for j in range(N):
            acc = f(0)
            for kb in range(k // 16):
                blk = f(f(f(sums[i, j, kb]) * sa[i, kb]) * sb[j, kb])
                acc = f(acc + blk)
            assert f32_bits(f(acc * ts)) == f32_bits(out[i, j])


def test_block_scaling_product_is_exact_in_float32():
    qa, qb = make_case(64, 202)
    sums = block_sums(qa, qb).astype(np.float64)
    exact = sums * e4m3_decode(qa.scales)[:, None, :] * e4m3_decode(qb.scales)[None, :, :]
    f = np.float32
    got = (sums.astype(f) * e4m3_decode(qa.scales).astype(f)[:, None, :]) * e4m3_decode(qb.scales).astype(f)[None, :, :]
    assert (got.astype(np.float64) == exact).all()


def test_case_arrays_layout_and_range():
    qa, qb = make_case(64, 202)
    nb, a, b, sa, sb, isum, out = case_arrays(qa, qb)
    assert nb == 4
    assert np.abs(a).max() <= 12 and np.abs(b).max() <= 12
    for kb in range(nb):
        assert (a[kb] @ b[kb] == isum[kb]).all()  # [i][k] @ [k][j]
    assert np.abs(isum).max() > 127  # would be clipped by an int8 mvout


def test_k16_case_padded_with_zeros():
    qa, qb = make_case(16, 101)
    nb, a, b, sa, sb, isum, out = case_arrays(qa, qb)
    assert nb == 1 and not a[1:].any() and not isum[1:].any()


def test_export_header(tmp_path):
    p = tmp_path / "d.h"
    export_c_header(p)
    text = p.read_text()
    assert text.count("0x") > 500 and "nvfp4_cases" in text
    assert len(re.findall(r"0x[0-9a-f]{8}u", text)) == 2 * M * N
    export_c_header(tmp_path / "d2.h")
    assert (tmp_path / "d2.h").read_text() == text  # deterministic


def test_k16_isum_exceeds_int8_somewhere():
    qa, qb = make_case(16, 101)
    assert np.abs(block_sums(qa, qb)).max() > 127
