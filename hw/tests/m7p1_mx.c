// M7.P1 / mxfp4-a, mxfp8-a: Berkeley MX Gemmini (MX base 266c593f), the COMMON workload: M=64 N=64 K=512, A and B = Gaussian
// make_inputs(seed 20261030) quantised with the MX branch recipe (refmodel/mx.py, E8M0 block scale per 32 K), checked BIT FOR BIT
// (BF16 output, any NaN equals any NaN) against refmodel/mx.py hw_matmul, the Level-H model M7.A proved bit-exact against Spike.
// Software = the branch's own style, as in hw/tests/m7a_mx.c: scales via MX_LOAD_SCALES ([K/32][M] and [K/32][N] E8M0 bytes), operands via
// mvin, one gemmini_loop_ws_spad, BF16 output left in the scratchpad and read back with flat mvouts. Define M7P1_FP4 or M7P1_FP8.
//   -DM7P1_CTL: control, flips one output bit before the check; it must FAIL (exit 1, 1 mismatch).
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "include/gemmini_testutils.h"
#ifdef M7P1_FP4
#include "m7p1_mx_fp4_data.h"
#define QUAD 1
#define M7P1_NAME "m7p1_mxfp4_64x64x512"
#else
#include "m7p1_mx_fp8_data.h"
#define QUAD 0
#define M7P1_NAME "m7p1_mxfp8_64x64x512"
#endif

#define DIM 16
#define TM (QUAD ? 2 * DIM : DIM)        // output rows per array pass
#define TN (QUAD ? 2 * DIM : DIM)
#define ELEM_DIV (QUAD ? 2 : 1)          // elements per byte

static uint8_t A_buf[MAX_AB_BYTES] __attribute__((aligned(64)));
static uint8_t B_buf[MAX_AB_BYTES] __attribute__((aligned(64)));
static uint8_t Asc_buf[4096] __attribute__((aligned(64)));
static uint8_t Bsc_buf[4096] __attribute__((aligned(64)));
static uint16_t C_hw[64 * 64] __attribute__((aligned(64)));
static uint32_t scale_factors[512] __attribute__((aligned(32)));

static int bf16_is_nan(uint16_t v) { return ((v & 0x7f80) == 0x7f80) && (v & 0x7f); }

int main() {
  const case_t *tc = &cases[0];
  const int M = tc->M, N = tc->N, K = tc->K;
  if (NCASES != 1 || M != 64 || N != 64 || K != 512) { printf(M7P1_NAME ": wrong data header\n"); return 2; }
  const int tiles_I = M / TM, tiles_J = N / TN, tiles_K = K / DIM;
  const int a_bytes = M * K / ELEM_DIV, b_bytes = K * N / ELEM_DIV, groups = (K + 31) / 32;
  if (a_bytes > MAX_AB_BYTES || b_bytes > MAX_AB_BYTES || groups * M > 4096 || groups * N > 4096) { printf("too big\n"); return 2; }
  memcpy(A_buf, tc->A, a_bytes);
  memcpy(B_buf, tc->B, b_bytes);
  memcpy(Asc_buf, tc->Asc, groups * M);
  memcpy(Bsc_buf, tc->Bsc, groups * N);
  memset(C_hw, 0xa5, sizeof(C_hw));

  const uint32_t a_base = 0;
  const uint32_t b_base = BANK_NUM * BANK_ROWS - tiles_K * tiles_J * DIM;
  const uint32_t spad_dest = a_base + tiles_I * tiles_K * DIM;
  const int c_rows = M * N * 2 / DIM;
  if (spad_dest + c_rows > b_base) { printf("does not fit the scratchpad\n"); return 2; }

  gemmini_flush(0);
  printf("M7P kernel start\n");
#ifdef M7P1_FP4
  gemmini_extended3_config_ex(WEIGHT_STATIONARY, 0, 0, ACC_SCALE_IDENTITY, 1, 1, 0, 0, false, 2, 2, 3, 0);
#else
  gemmini_extended3_config_ex(WEIGHT_STATIONARY, 0, 0, ACC_SCALE_IDENTITY, 1, 1, 0, 0, false, 0, 0, 3, 0);
#endif
  gemmini_mx_load_scales((uint64_t)Asc_buf, groups * M, 0);
  gemmini_mx_load_scales((uint64_t)Bsc_buf, groups * N, 1);
  gemmini_fence();

  gemmini_config_ld(K);                  // A rows are K bytes: one row per M row (FP8) or per packed pair of M rows (FP4)
  for (int i = 0; i < tiles_I; i++)
    for (int k = 0; k < tiles_K; k++) {
      const uint8_t *src = A_buf + i * DIM * K + k * DIM;
      gemmini_extended_mvin((void *)src, a_base + (i * tiles_K + k) * DIM, DIM, DIM);
    }
  gemmini_config_ld(N / ELEM_DIV);
  for (int k = 0; k < tiles_K; k++)
    for (int j = 0; j < tiles_J; j++) {
      const uint8_t *src = B_buf + k * DIM * (N / ELEM_DIV) + j * DIM;
      gemmini_extended_mvin((void *)src, b_base + (k * tiles_J + j) * DIM, DIM, DIM);
    }

  gemmini_config_st(N * 2);
  gemmini_mxquant_config_mvout((uint64_t)scale_factors, tiles_I, tiles_J, tiles_K, 0, 0, 1);
  gemmini_loop_ws_spad(tiles_I, tiles_J, tiles_K, 0, 0, 0, a_base, BANK_NUM * BANK_ROWS, 0, spad_dest,
                       false, false, false, false, false, NO_ACTIVATION, 0, 0, false, 0x38);
  gemmini_fence();
  gemmini_config_st(DIM * sizeof(uint8_t));
  uint8_t *cb = (uint8_t *)C_hw;
  for (int r = 0; r < c_rows; r += DIM)
    gemmini_extended_mvout(cb + r * DIM, spad_dest + r, DIM, DIM);
  gemmini_fence();
  printf("M7P kernel end\n");
#ifdef M7P1_CTL
  C_hw[37 * 64 + 11] ^= 1;
#endif
  long checked = 0, bad = 0, nan_cnt = 0;
  for (int i = 0; i < M; ++i)
    for (int j = 0; j < N; ++j) {
      uint16_t got = C_hw[i * N + j], want = tc->C[i * N + j];
      int same = got == want || (bf16_is_nan(got) && bf16_is_nan(want));
      nan_cnt += bf16_is_nan(want);
      ++checked;
      if (!same) { if (bad < 8) printf("MISMATCH C[%d][%d]: got 0x%04x want 0x%04x\n", i, j, got, want); ++bad; }
    }
  printf(M7P1_NAME ": %ld outputs checked, %ld bad, %ld NaN expected\n", checked, bad, nan_cnt);
  return (bad != 0 || checked != 64 * 64);
}
