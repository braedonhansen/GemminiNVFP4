// M6.3C: first end-to-end NVFP4 matmul in RTL (Verilator, NvFp4GemminiRocketConfig). M = N = 32, K = 64.
//
// mvin packed E2M1 A and B (MX FP4 quad layouts), load the E4M3 block scales (16 elements) with MX_LOAD_SCALES, run the
// weight-stationary loop (NvFp4Mesh -> exact scale stage -> FP32 accumulate), store the accumulator to the scratchpad as
// FP32 with the tensor scale applied at mvout through acc_scale (out = acc * ((tA*tB)*0.25f), RNE float32), read the FP32
// rows back to DRAM, and compare every output's BITS with the refmodel (refmodel/export_e2e.py, hw_matmul_v0 order).
// Exit code 0 only if there are 0 mismatches. Spike cannot run this yet (that is M6.4): Verilator only.

#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "include/gemmini_testutils.h"
#include "nvfp4_e2e_data.h"

#define DIM 16
#define ADDR_LEN 32

static inline uint64_t rdcycle(void) {
  uint64_t c;
  asm volatile("rdcycle %0" : "=r"(c));
  return c;
}

static inline uint32_t f2u(float f) {
  uint32_t u;
  memcpy(&u, &f, sizeof u);
  return u;
}

int main() {
  static uint32_t C_hw[E2E_M][E2E_N] __attribute__((aligned(64)));
  uint32_t scale_factors[512] __attribute__((aligned(32))) = {0};
  memset(C_hw, 0xa5, sizeof(C_hw));

  const int tiles_I = E2E_M / DIM / 2;   // 32-row quad tiles
  const int tiles_J = E2E_N / DIM / 2;   // 32-column quad tiles
  const int tiles_K = E2E_K / DIM;
  const uint32_t a_base = 0;
  const uint32_t b_base = BANK_NUM * BANK_ROWS - tiles_K * tiles_J * DIM;
  const int SPAD_DEST = 128;

  // the tensor-scale factor in the refmodel's float32 order: (tA*tB)*0.25f, each op one IEEE RNE op (the Makefile builds with -ffast-math)
  volatile float fac = tA * tB;
  fac = fac * 0.25f;
  float factor = fac;

  gemmini_flush(0);
  uint64_t t0 = rdcycle();
  gemmini_extended3_config_ex(WEIGHT_STATIONARY, 0, 0, ACC_SCALE_IDENTITY, 1, 1, 0, 0, false, 2, 2, 3, 0);
  gemmini_mx_load_scales((uint64_t)&A_sc, sizeof(A_sc), 0);
  gemmini_mx_load_scales((uint64_t)&B_sc, sizeof(B_sc), 1);
  gemmini_fence();

  gemmini_config_ld(E2E_K * sizeof(uint8_t));
  for (int i = 0; i < tiles_I; i++)
    for (int k = 0; k < tiles_K; k++) {
      const uint8_t *src = &A_in_hw[0][0] + i * DIM * E2E_K + k * DIM;
      gemmini_extended_mvin((void *)src, a_base + (i * tiles_K + k) * DIM, DIM, DIM);
    }
  gemmini_config_ld(E2E_N / 2);
  for (int k = 0; k < tiles_K; k++)
    for (int j = 0; j < tiles_J; j++) {
      const uint8_t *src = &B_in[0][0] + k * DIM * (E2E_N / 2) + j * DIM;
      gemmini_extended_mvin((void *)src, b_base + (k * tiles_J + j) * DIM, DIM, DIM);
    }

  // mvout config: the tensor-scale factor travels in acc_scale (CONFIG_ST rs2[63:32], one FP32); the stride is unused by the spad store
  gemmini_extended_config_st(DIM * sizeof(uint32_t), NO_ACTIVATION, factor);
  gemmini_mxquant_config_mvout((uint64_t)scale_factors, tiles_I, tiles_J, tiles_K, 0, 0, 1);
  gemmini_loop_ws_spad(tiles_I, tiles_J, tiles_K, 0, 0, 0, a_base, BANK_NUM * BANK_ROWS, 0, SPAD_DEST,
                       false, false, false, false, false, NO_ACTIVATION, 0, 0, false, 0x38);
  gemmini_fence();

  // FP32 rows are now row-major in the scratchpad (8 spad rows of 4 x FP32 per 32-column output row): copy them to DRAM
  gemmini_config_st(DIM * sizeof(uint8_t));
  const int total_spad_rows = E2E_M * E2E_N * (int)sizeof(uint32_t) / DIM;
  uint8_t *c_base = (uint8_t *)C_hw;
  for (int r = 0; r < total_spad_rows; r += DIM)
    gemmini_extended_mvout(c_base + r * DIM, SPAD_DEST + r, DIM, DIM);
  gemmini_fence();
  uint64_t cycles = rdcycle() - t0;

  int errors = 0;
  for (int i = 0; i < E2E_M; i++)
    for (int j = 0; j < E2E_N; j++)
      if (C_hw[i][j] != out_bits[i][j]) {
        if (errors < 16)
          printf("MISMATCH out[%d][%d]: got 0x%08x want 0x%08x\n", i, j, (unsigned)C_hw[i][j], (unsigned)out_bits[i][j]);
        errors++;
      }
  printf("factor bits 0x%08x\n", (unsigned)f2u(factor));
  printf("nvfp4_e2e M=%d K=%d N=%d: %d mismatches of %d outputs, %lu cycles (config + loads + matmul + mvout)\n",
         E2E_M, E2E_K, E2E_N, errors, E2E_M * E2E_N, (unsigned long)cycles);
  return errors != 0;
}
