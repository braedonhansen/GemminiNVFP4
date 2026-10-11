import numpy as np
import pytest
from formats import e4m3_decode
from quant import quantize, concat_rows, BLOCK


def rand(shape, seed=0, spread=2.0):
    rng = np.random.default_rng(seed)
    return rng.standard_normal(shape) * 10.0 ** rng.uniform(-spread, spread, (shape[0], 1))


def test_shapes_and_padding():
    q = quantize(rand((3, 20)))
    assert q.codes.shape == (3, 32) and q.scales.shape == (3, 2) and q.k == 20
    assert q.dequantize().shape == (3, 20)


def test_partial_block_padded_with_zeros():
    q = quantize(rand((2, 5)))
    assert (q.codes[:, 5:] == 0).all()


def test_codes_are_4_bit_and_scales_finite():
    q = quantize(rand((8, 48)))
    assert q.codes.max() <= 15
    assert not np.isnan(e4m3_decode(q.scales)).any()


def test_tensor_scale_formula():
    x = rand((4, 32))
    q = quantize(x)
    expect = np.float32(np.abs(x).max() / (6 * 448))
    assert abs(float(q.tensor_scale[0]) - float(expect)) <= float(expect) * 2 ** -23


def test_tensor_scale_covers_amax():
    for s in range(50):
        x = rand((4, 32), seed=s)
        assert float(quantize(x).tensor_scale[0]) * 2688 >= np.abs(x).max()


@pytest.mark.parametrize("seed", range(8))
def test_scale_round_up_never_clips(seed):
    x = rand((16, 64), seed=seed, spread=3.0)
    q = quantize(x)
    sc = e4m3_decode(q.scales).repeat(BLOCK, axis=1) * float(q.tensor_scale[0])
    assert (np.abs(x) <= 6 * sc).all()


def test_block_scale_at_most_448_and_hit_by_max_block():
    q = quantize(rand((6, 32), seed=3))
    s = e4m3_decode(q.scales)
    assert s.max() <= 448 and s.max() == 448


def test_dequantize_error_bounded():
    x = rand((4, 64), seed=5, spread=0.5)
    q = quantize(x)
    sc = e4m3_decode(q.scales).repeat(BLOCK, axis=1) * float(q.tensor_scale[0])
    err = np.abs(q.dequantize() - x)
    assert (err <= 1.0 * sc + 1e-12).all()  # half the widest E2M1 gap (2) = 1 step


def test_zero_tensor_and_zero_block():
    q = quantize(np.zeros((2, 16)))
    assert (q.dequantize() == 0).all()
    x = np.zeros((1, 32))
    x[0, 20] = 3.0
    q = quantize(x)
    assert q.scales[0, 0] == 0 and q.dequantize()[0, 20] > 0


def test_signs_preserved():
    x = rand((4, 16), seed=9)
    d = quantize(x).dequantize()
    assert ((np.sign(d) == np.sign(x)) | (d == 0)).all()


def test_concat_rows_keeps_per_row_tensor_scale():
    rows = [quantize(rand((1, 4), seed=s) * (s + 1)) for s in range(3)]
    cat = concat_rows(rows)
    assert cat.codes.shape == (3, 16) and cat.tensor_scale.shape == (3,)
    assert np.array_equal(cat.dequantize()[1], rows[1].dequantize()[0])
