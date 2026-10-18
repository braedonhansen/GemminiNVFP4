import json
from vectors import export
from hw_dot import code_to_int


def test_pair_vectors_complete_and_exact(tmp_path):
    pairs, _ = export(tmp_path)
    assert len(pairs) == 256 and len({(p["a"], p["b"]) for p in pairs}) == 256
    for p in pairs:
        assert p["product"] == int(code_to_int(p["a"])) * int(code_to_int(p["b"]))
    lines = (tmp_path / "e2m1_pairs.hex").read_text().split()
    assert len(lines) == 256 and int(lines[0x77], 16) == 144


def test_block_vectors_self_consistent(tmp_path):
    _, blocks = export(tmp_path)
    for b in blocks:
        s = sum(int(code_to_int(x)) * int(code_to_int(y)) for x, y in zip(b["a_codes"], b["b_codes"]))
        assert s == b["int_sum"] and -4096 <= s <= 4095
    assert any(b["int_sum"] == 2304 for b in blocks) and any(b["int_sum"] == -2304 for b in blocks)
    hexlines = (tmp_path / "blocks.hex").read_text().splitlines()
    assert len(hexlines) == len(blocks) and all(len(l.split()) == 8 for l in hexlines)
    assert json.loads((tmp_path / "blocks.json").read_text()) == blocks


def test_mesh_passes_exact_and_cover_refmodel_blocks(tmp_path):
    from vectors import mesh_pass_vectors
    from hw_dot import code_to_int, mesh_block_sums
    import numpy as np
    seen = set()
    for p in mesh_pass_vectors(16):
        a, b, c = p["A"], p["B"], p["C"]
        assert a.shape == (32, 16) and b.shape == (16, 32) and c.shape == (32, 32)
        ref = np.zeros((32, 32), np.int64)
        for m in range(32):
            for n in range(32):
                ref[m, n] = sum(int(code_to_int(a[m, k])) * int(code_to_int(b[k, n])) for k in range(16))
        assert (ref == c).all() and (c == mesh_block_sums(a, b)).all()
        assert c.min() >= -2304 and c.max() <= 2304
        for i, isum in p.get("diag_blocks", []):
            assert c[i, i] == isum
        seen.add(p["name"])
    passes = {p["name"]: p for p in mesh_pass_vectors(16)}
    assert (passes["max_pos"]["C"] == 2304).all() and (passes["max_neg"]["C"] == -2304).all()
    assert (passes["neg_neg"]["C"] == 2304).all() and (passes["zeros"]["C"] == 0).all()
    assert (passes["neg_zero"]["C"] == 0).all() and (passes["alt_k"]["C"] == 0).all()
    assert sorted({abs(int(x)) for x in passes["checker"]["C"].flat}) == [2304]
    covered = sum(len(p.get("diag_blocks", [])) for p in mesh_pass_vectors(16))
    assert covered == 67  # all refmodel blocks appear on a pass diagonal


def test_mesh_pass_files_written(tmp_path):
    export(tmp_path)
    for name, dim in (("mesh_passes_d16.txt", 16), ("mesh_passes_d4.txt", 4)):
        lines = (tmp_path / name).read_text().splitlines()
        heads = [l for l in lines if l.startswith("PASS ")]
        assert heads and all(h.split()[2:] == [str(2 * dim), str(dim), str(2 * dim)] for h in heads)
        assert len(lines) == len(heads) * (1 + 2 * 2 * dim + dim)
    assert len([l for l in (tmp_path / "mesh_passes_d4.txt").read_text().splitlines() if l.startswith("PASS ")]) >= 200
