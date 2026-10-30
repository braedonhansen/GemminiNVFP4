// M7.P1 / int8-stock-b: activity workload for the Cadence power flow. Stock INT8 Gemmini (upstream 8c3f9923, DIM=16, GemminiRocketConfig),
// the COMMON workload of all five designs: M=64 N=64 K=512, A and B = Gaussian make_inputs(seed 20261030) quantised with the INT8
// per-tensor recipe (refmodel/int8.py), through the stock library path (tiled_matmul_auto, weight-stationary), FULL-WIDTH INT32 output.
// Data: m7p1_int8_data.h from refmodel/export_m7p1.py (expected C = exact integer matmul; this is the Level-H model that M7.A proved
// bit-exact against Spike for this software path). All 4096 outputs are compared after the kernel (outside the measured window).
//   -DM7P1_CTL: control variant, flips one output bit before the check; it must FAIL (exit 1, 1 mismatch).
// Exit 0 only if 4096 outputs were compared and none mismatched.
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include "include/gemmini_testutils.h"
#include "m7p1_int8_data.h"

static elem_t A_buf[64 * 512] row_align(1);
static elem_t B_buf[512 * 64] row_align(1);
static acc_t C_buf[64 * 64] row_align(1);

int main() {
  const case_t *tc = &cases[0];
  if (NCASES != 1 || tc->M != 64 || tc->N != 64 || tc->K != 512) { printf("m7p1_int8: wrong data header\n"); return 2; }
  gemmini_flush(0);
  memcpy(A_buf, tc->A, (size_t)tc->M * tc->K);
  memcpy(B_buf, tc->B, (size_t)tc->K * tc->N);
  for (int i = 0; i < tc->M * tc->N; ++i) C_buf[i] = 0x7eadbeef;   // poison
  printf("M7P kernel start\n");
  tiled_matmul_auto(tc->M, tc->N, tc->K, A_buf, B_buf, NULL, C_buf,
                    tc->K, tc->N, tc->N, tc->N,
                    MVIN_SCALE_IDENTITY, MVIN_SCALE_IDENTITY, MVIN_SCALE_IDENTITY,
                    NO_ACTIVATION, ACC_SCALE_IDENTITY, 0, false,
                    false, false,
                    true, false,   // full_C: INT32 output
                    0, WS);
  gemmini_fence();
  printf("M7P kernel end\n");
#ifdef M7P1_CTL
  C_buf[37 * 64 + 11] ^= 1;
#endif
  long checked = 0, bad = 0;
  for (int i = 0; i < tc->M; ++i)
    for (int j = 0; j < tc->N; ++j) {
      int32_t got = C_buf[i * tc->N + j], want = tc->C[i * tc->N + j];
      ++checked;
      if (got != want) { if (bad < 8) printf("C[%d][%d]: got %d want %d\n", i, j, (int)got, (int)want); ++bad; }
    }
  printf("m7p1_int8_64x64x512: %ld outputs checked, %ld bad\n", checked, bad);
  return (bad != 0 || checked != 64 * 64);
}
