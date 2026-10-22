// M7.A / A3d: Berkeley MX Gemmini (~/chipyard-mx, 266c593f, spike --extension=gemmini) matmul checked BIT FOR BIT against
// refmodel/mx.py hw_matmul, many matrices per binary. One binary per element format (define M7A_FP4 or M7A_FP8 and
// M7A_DATA before including): FP4 = E2M1 x E2M1 quad tiles (32x32 per pass), FP8 = E4M3 x E4M3 single tiles (16x16).
// Layout follows the MX branch's own tests (matmul_tiled_fp4_64x64.c / matmul_tiled_fp8_64x64.c): scales via
// MX_LOAD_SCALES ([K/32][M] and [K/32][N] E8M0 bytes), operands via mvin, one gemmini_loop_ws_spad, BF16 output in the
// scratchpad read back with flat mvouts. Cases that overflow the accumulator (OCP-recipe data) produce inf/NaN: any NaN
// matches any NaN. Exit 0 iff >= 1 case ran and every output matched.
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "include/gemmini_testutils.h"
#include M7A_DATA

#define DIM 16
#ifdef M7A_FP4
#define QUAD 1
#else
#define QUAD 0
#endif
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
  long total = 0, bad = 0, cases_bad = 0;
  int ran = 0;
  gemmini_flush(0);
  for (int c = 0; c < NCASES; ++c) {
    const case_t *tc = &cases[c];
    const int M = tc->M, N = tc->N, K = tc->K;
    const int tiles_I = M / TM, tiles_J = N / TN, tiles_K = K / DIM;
    const int a_bytes = M * K / ELEM_DIV, b_bytes = K * N / ELEM_DIV, groups = (K + 31) / 32;
    if (a_bytes > MAX_AB_BYTES || b_bytes > MAX_AB_BYTES || groups * M > 4096 || groups * N > 4096) { printf("case %d too big\n", c); return 2; }
    memcpy(A_buf, tc->A, a_bytes);
    memcpy(B_buf, tc->B, b_bytes);
    memcpy(Asc_buf, tc->Asc, groups * M);
    memcpy(Bsc_buf, tc->Bsc, groups * N);
    memset(C_hw, 0xa5, sizeof(C_hw));

    const uint32_t a_base = 0;
    const uint32_t b_base = BANK_NUM * BANK_ROWS - tiles_K * tiles_J * DIM;
    const uint32_t spad_dest = a_base + tiles_I * tiles_K * DIM;
    const int c_rows = M * N * 2 / DIM;
    if (spad_dest + c_rows > b_base) { printf("case %d does not fit the scratchpad\n", c); return 2; }

#ifdef M7A_FP4
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

    long cbad = 0;
    for (int i = 0; i < M; ++i)
      for (int j = 0; j < N; ++j) {
        uint16_t got = C_hw[i * N + j], want = tc->C[i * N + j];
        int same = got == want || (bf16_is_nan(got) && bf16_is_nan(want));
        if (!same) {
          if (bad + cbad < 8) printf("MISMATCH case %d (%s) C[%d][%d]: got 0x%04x want 0x%04x\n", c, tc->name, i, j, got, want);
          ++cbad;
        }
      }
    printf("case %2d %-24s M=%2d N=%2d K=%5d: %ld mismatches of %d\n", c, tc->name, M, N, K, cbad, M * N);
    total += M * N; bad += cbad; cases_bad += cbad != 0; ++ran;
  }
  printf(M7A_NAME ": %d cases, %ld outputs, %ld mismatches (%ld cases with a mismatch)\n", ran, total, bad, cases_bad);
  return (bad != 0 || ran < 1 || total == 0);
}
