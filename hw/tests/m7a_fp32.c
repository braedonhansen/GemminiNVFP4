// M7.A / A3c: stock FP32 Gemmini (upstream 8c3f9923 FPGemminiRocketConfig = GemminiFPConfigs.FP32DefaultConfig, DIM=4)
// matmul through the stock software path (tiled_matmul_auto, weight-stationary), output compared BIT FOR BIT with two
// refmodel variants: CS (separate multiply and add per PE step, what libgemmini's functional model computes) and CF
// (fused multiply-add PE, what Arithmetic.scala describes). Spike can only agree with one of them. Prints both counts;
// exits 0 iff the CS (Spike-verifiable) variant has 0 mismatches and at least one case ran.
// Needs a libgemmini and a rocc-tests include dir built for the FP32 config (logs/m7a-fp32.sh).
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include "include/gemmini_testutils.h"
#include "m7a_fp32_data.h"

#define MAXA (16 * 16384)
#define MAXC (64 * 64)
static elem_t A_buf[MAXA] row_align(1);
static elem_t B_buf[MAXA] row_align(1);
static elem_t C_buf[MAXC] row_align(1);

static inline uint32_t f2u(float f) { uint32_t u; memcpy(&u, &f, sizeof u); return u; }

int main() {
  gemmini_flush(0);
  long total = 0, bad_sep = 0, bad_fused = 0;
  int ran = 0;
  for (int c = 0; c < NCASES; ++c) {
    const case_t *tc = &cases[c];
    if ((size_t)tc->M * tc->K > MAXA || (size_t)tc->K * tc->N > MAXA) { printf("case %d too big\n", c); return 2; }
    memcpy(A_buf, tc->A, sizeof(float) * (size_t)tc->M * tc->K);
    memcpy(B_buf, tc->B, sizeof(float) * (size_t)tc->K * tc->N);
    for (int i = 0; i < tc->M * tc->N; ++i) { uint32_t p = 0x7fc0dead; memcpy(&C_buf[i], &p, 4); }   // NaN poison
    tiled_matmul_auto(tc->M, tc->N, tc->K, A_buf, B_buf, NULL, C_buf,
                      tc->K, tc->N, tc->N, tc->N,
                      MVIN_SCALE_IDENTITY, MVIN_SCALE_IDENTITY, MVIN_SCALE_IDENTITY,
                      NO_ACTIVATION, ACC_SCALE_IDENTITY, 0, false,
                      false, false,
                      false, false,
                      0, WS);
    long bs = 0, bf = 0;
    for (int i = 0; i < tc->M; ++i)
      for (int j = 0; j < tc->N; ++j) {
        uint32_t got = f2u(C_buf[i * tc->N + j]);
        uint32_t ws = tc->C_sep[i * tc->N + j], wf = tc->C_fused[i * tc->N + j];
        if (got != ws) { if (bad_sep + bs < 8) printf("case %d C[%d][%d]: got 0x%08x want(sep) 0x%08x\n", c, i, j, (unsigned)got, (unsigned)ws); ++bs; }
        if (got != wf) ++bf;
      }
    printf("case %d (M=%d N=%d K=%d): sep %ld mismatches, fused %ld mismatches, of %d\n", c, tc->M, tc->N, tc->K, bs, bf, tc->M * tc->N);
    total += tc->M * tc->N; bad_sep += bs; bad_fused += bf; ++ran;
  }
  printf("m7a_fp32: %d cases, %ld outputs: separate-model mismatches %ld, fused-model mismatches %ld\n", ran, total, bad_sep, bad_fused);
  return (bad_sep != 0 || ran < 1 || total == 0);
}
