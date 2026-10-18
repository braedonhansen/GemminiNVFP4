// TEMPORARY scratch test (not committed to any repo): M5 matmul_tiled_fp4_64x64 with NVFP4 16-element scale blocks.
// A/B FP4 data from matmul_fp4_64x64.h; scales: 4 K-blocks of 16, E4M3 bytes below (must match logs/m6.3b-nvcheck.py).
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "include/gemmini_testutils.h"
#include "include/matmul_fp4_64x64.h"
#define DIM 16
#define ADDR_LEN 32
typedef uint8_t elem_t;
// E4M3 scale bytes: A_s[kblock][m], B_s[kblock][n]; deterministic generator mirrored in the python checker
static uint8_t A_s[4][64] __attribute__((aligned(8)));
static uint8_t B_s[4][64] __attribute__((aligned(8)));
static uint8_t gen(uint32_t kk, uint32_t idx, uint32_t sel) {
  uint32_t x = kk * 7919u + idx * 104729u + sel * 13u + 12345u;
  x ^= x << 13; x ^= x >> 17; x ^= x << 5;
  uint32_t e = 4 + (x % 8);        // exponent field 4..11
  uint32_t m = (x >> 8) & 7;       // mantissa 0..7
  if ((x >> 20) % 29 == 0) { e = 0; m = (x >> 12) & 7; }   // a few subnormals / zero codes
  return (uint8_t)((e << 3) | m);
}
int main() {
  static uint64_t C_hw[64][16];
  uint32_t scale_factors[512] __attribute__((aligned(32))) = {0};
  for (int k = 0; k < 4; k++) for (int i = 0; i < 64; i++) { A_s[k][i] = gen(k, i, 1); B_s[k][i] = gen(k, i, 2); }
  int tiles_I = MATMUL_M / DIM / 2, tiles_J = MATMUL_N / DIM / 2, tiles_K = MATMUL_K / DIM;
  uint32_t a_base = 0;
  uint32_t b_base = BANK_NUM * BANK_ROWS - tiles_K * tiles_J * DIM;
  gemmini_flush(0);
  gemmini_extended3_config_ex(WEIGHT_STATIONARY, 0, 0, ACC_SCALE_IDENTITY, 1, 1, 0, 0, false, 2, 2, 3, 0);
  gemmini_mx_load_scales((uint64_t)&A_s, sizeof(A_s), 0);
  gemmini_mx_load_scales((uint64_t)&B_s, sizeof(B_s), 1);
  gemmini_fence();
  gemmini_config_ld(MATMUL_M * sizeof(elem_t));
  for (int i = 0; i < tiles_I; i++) for (int k = 0; k < tiles_K; k++) {
    elem_t *dram_ptr = ((elem_t*)A_in_hw) + i * DIM * MATMUL_M + k * DIM;
    gemmini_extended_mvin((void *) dram_ptr, a_base + (i * tiles_K + k) * DIM, DIM, DIM);
  }
  gemmini_config_ld(MATMUL_N * sizeof(elem_t) / 2)
  for (int k = 0; k < tiles_K; k++) for (int j = 0; j < tiles_J; j++) {
    elem_t *dram_ptr = ((elem_t*)B_in) + k * DIM * MATMUL_N / 2 + j * DIM;
    gemmini_extended_mvin((void *) dram_ptr, b_base + (k * tiles_J + j) * DIM, DIM, DIM);
  }
  int SPAD_DEST = 128;
  gemmini_config_st(16 * sizeof(uint64_t));
  gemmini_mxquant_config_mvout((uint64_t)scale_factors, tiles_I, tiles_J, tiles_K, 0, 0, 1);
  gemmini_loop_ws_spad(tiles_I, tiles_J, tiles_K, 0, 0, 0, a_base, BANK_NUM * BANK_ROWS, 0, SPAD_DEST,
      false, false, false, false, false, NO_ACTIVATION, 0, 0, false, 0x38);
  gemmini_fence();
  printf("NVSMOKE done\n");
  return 0;
}
