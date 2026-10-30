"""M7.P1: data headers for the common power workload (hw/tests/m7p1_*): M=64, N=64, K=512, Gaussian, ONE seed for all five designs.

  python refmodel/export_m7p1.py <outdir>          writes m7p1_{int8,fp32,mx_fp8,mx_fp4,mx_fp4ctl,nvfp4}_data.h

A and B are `accuracy_sweep.make_inputs("gaussian", 512, SEED, 64, 64)` for every design (float64); each design then quantises them with its
own M7.A Level-H recipe (INT8 per-tensor, MX branch recipe, NVFP4 refmodel, FP32 cast) and the expected output comes from that design's
Level-H model, the same functions export_m7a.py uses for the M7.A Spike checks (those were proven bit-exact against Spike).
Prints sha256 of A and B (float64 bytes) so the "same source matrices" claim is checkable.
"""
import hashlib
import sys
from pathlib import Path
import numpy as np
sys.path.insert(0, str(Path(__file__).resolve().parent))
import accuracy_sweep as sw
import export_m7a as ex

SEED = 20261030
M, N, K = 64, 64, 512
DIST = "gaussian"


def source_hash():
    a, b = sw.make_inputs(DIST, K, SEED, M, N)
    assert a.shape == (M, K) and b.shape == (K, N)
    return hashlib.sha256(a.tobytes()).hexdigest()[:16], hashlib.sha256(b.tobytes()).hexdigest()[:16]


def main(outdir):
    out = Path(outdir)
    out.mkdir(parents=True, exist_ok=True)
    ha, hb = source_hash()
    print(f"source: {DIST} M={M} N={N} K={K} seed={SEED}  sha256(A)={ha} sha256(B)={hb}")
    ex.INT8_CASES[:] = [(DIST, M, N, K, SEED)]
    ex.export_int8(out / "m7p1_int8_data.h")
    ex.FP32_CASES[:] = [(DIST, M, N, K, SEED)]
    ex.export_fp32(out / "m7p1_fp32_data.h")
    ex.mx_cases = lambda fmt: [(f"gaussian_{M}x{N}x{K}", DIST, M, N, K, SEED, "branch")]
    ex.export_mx(out / "m7p1_mx_fp8_data.h", "fp8")
    ex.export_mx(out / "m7p1_mx_fp4_data.h", "fp4")
    ex.export_nvfp4(out / "m7p1_nvfp4_data.h", DIST, SEED, M, N, K)


if __name__ == "__main__":
    main(sys.argv[1])
