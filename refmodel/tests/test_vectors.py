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
