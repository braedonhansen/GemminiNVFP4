// M7.P1 / fp32-stock-a: stock FP32 Gemmini (upstream 8c3f9923 FPGemminiRocketConfig, DIM=4), the COMMON workload: M=64 N=64 K=512,
// A and B = Gaussian make_inputs(seed 20261030) cast to float32, through the stock path (tiled_matmul_auto, weight-stationary),
// FP32 output. Expected values: refmodel hw_models (export_m7p1.py), BOTH variants, compared bit for bit:
//   sep   = separate multiply and add (what libgemmini/Spike computes; M7.A proved it bit-exact against Spike)
//   fused = fused multiply-add (what Arithmetic.scala describes; unverified against RTL until this test)
// The test passes (exit 0) iff ONE of the two models matches all 4096 outputs bit for bit; it prints both counts and says which one.
//   -DM7P1_CTL: control, flips one output bit before the check; it must FAIL (neither model matches).
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include "include/gemmini_testutils.h"
#include "m7p1_fp32_data.h"

static elem_t A_buf[64 * 512] row_align(1);
static elem_t B_buf[512 * 64] row_align(1);
static elem_t C_buf[64 * 64] row_align(1);

static inline uint32_t f2u(float f) { uint32_t u; memcpy(&u, &f, sizeof u); return u; }

int main() {
  const case_t *tc = &cases[0];
  if (NCASES != 1 || tc->M != 64 || tc->N != 64 || tc->K != 512) { printf("m7p1_fp32: wrong data header\n"); return 2; }
  gemmini_flush(0);
  memcpy(A_buf, tc->A, sizeof(float) * 64 * 512);
  memcpy(B_buf, tc->B, sizeof(float) * 512 * 64);
  for (int i = 0; i < 64 * 64; ++i) { uint32_t p = 0x7fc0dead; memcpy(&C_buf[i], &p, 4); }   // NaN poison
  printf("M7P kernel start\n");
  tiled_matmul_auto(tc->M, tc->N, tc->K, A_buf, B_buf, NULL, C_buf,
                    tc->K, tc->N, tc->N, tc->N,
                    MVIN_SCALE_IDENTITY, MVIN_SCALE_IDENTITY, MVIN_SCALE_IDENTITY,
                    NO_ACTIVATION, ACC_SCALE_IDENTITY, 0, false,
                    false, false,
                    false, false,
                    0, WS);
  gemmini_fence();
  printf("M7P kernel end\n");
#ifdef M7P1_CTL
  { uint32_t u = f2u(C_buf[37 * 64 + 11]) ^ 1u; memcpy(&C_buf[37 * 64 + 11], &u, 4); }
#endif
  long checked = 0, bad_sep = 0, bad_fused = 0;
  for (int i = 0; i < 64; ++i)
    for (int j = 0; j < 64; ++j) {
      uint32_t got = f2u(C_buf[i * 64 + j]);
      uint32_t ws = tc->C_sep[i * 64 + j], wf = tc->C_fused[i * 64 + j];
      ++checked;
      if (got != ws) { if (bad_sep < 4) printf("C[%d][%d]: got 0x%08x want(sep) 0x%08x\n", i, j, (unsigned)got, (unsigned)ws); ++bad_sep; }
      if (got != wf) { if (bad_fused < 4) printf("C[%d][%d]: got 0x%08x want(fused) 0x%08x\n", i, j, (unsigned)got, (unsigned)wf); ++bad_fused; }
    }
  printf("m7p1_fp32_64x64x512: %ld outputs checked, separate-model mismatches %ld, fused-model mismatches %ld\n", checked, bad_sep, bad_fused);
  return (checked != 64 * 64 || (bad_sep != 0 && bad_fused != 0));
}
