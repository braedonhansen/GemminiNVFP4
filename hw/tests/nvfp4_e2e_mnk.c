// M6.5: multi-tile NVFP4 matmul, generalised from nvfp4_e2e.c (M6.3C). Sizes come from the data header (E2E_M, E2E_N, E2E_K:
// M and N multiples of 32, K a multiple of 16). Not built by itself: each shape has a one-line wrapper that defines
// E2E_DATA_HEADER / E2E_NAME and includes this file, so there is one binary per shape. Runs unchanged in Spike
// (--extension=gemmini_nvfp4) and in Verilator (NvFp4GemminiRocketConfig). Multi-tile uses the loop instruction
// (loop_ws_spad with tiles_I x tiles_J x tiles_K), no tile is unrolled in software.
//
// Original M6.3C description (M = N = 32, K = 64):
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
#ifndef E2E_DATA_HEADER
#error "define E2E_DATA_HEADER (and E2E_NAME) before including nvfp4_e2e_mnk.c; see the nvfp4_mt_*.c wrappers"
#endif
#include E2E_DATA_HEADER
#ifndef E2E_NAME
#define E2E_NAME "nvfp4_e2e_mnk"
#endif

#define DIM 16
#define ADDR_LEN 32

// Capacity checks from gemmini_params_nvfp4.h (all in units of 16-byte scratchpad rows / accumulator rows).
#define TILES_I (E2E_M / DIM / 2)
#define TILES_J (E2E_N / DIM / 2)
#define TILES_K (E2E_K / DIM)
#define SPAD_ROWS (BANK_NUM * BANK_ROWS)
#define A_ROWS (TILES_I * TILES_K * DIM)                  // A tiles, i-major
#define B_ROWS (TILES_K * TILES_J * DIM)                  // B tiles, k-major
#define C_ROWS (E2E_M * E2E_N * 4 / DIM)                  // FP32 output, 4 per 16-byte row, row-major
#define SPAD_DEST BANK_ROWS                               // the output region starts at bank 1
_Static_assert(E2E_M % 32 == 0 && E2E_N % 32 == 0 && E2E_K % 16 == 0, "shape must be quad tiles (32) x K blocks (16)");
_Static_assert(A_ROWS <= SPAD_DEST, "A region (rows 0..) must end below the output region");
_Static_assert(SPAD_DEST + C_ROWS <= SPAD_ROWS - B_ROWS, "output region must end below the B region at the top of the scratchpad");
_Static_assert(B_ROWS + A_ROWS + C_ROWS <= SPAD_ROWS, "A + B + C must fit the scratchpad");
_Static_assert(TILES_I * TILES_J * DIM <= ACC_ROWS, "accumulator rows needed (16 per quad tile) exceed ACC_ROWS");
_Static_assert((E2E_K / 16) * E2E_M <= 4096 && (E2E_K / 16) * E2E_N <= 4096, "scale bytes per operand exceed the 4096-byte window");
_Static_assert(C_ROWS % DIM == 0, "output copy works in 16-row mvouts");

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

  const int tiles_I = TILES_I;   // 32-row quad tiles
  const int tiles_J = TILES_J;   // 32-column quad tiles
  const int tiles_K = TILES_K;
  const uint32_t a_base = 0;
  const uint32_t b_base = BANK_NUM * BANK_ROWS - tiles_K * tiles_J * DIM;

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
  printf(E2E_NAME " M=%d K=%d N=%d: %d mismatches of %d outputs, %lu cycles (config + loads + matmul + mvout)\n",
         E2E_M, E2E_K, E2E_N, errors, E2E_M * E2E_N, (unsigned long)cycles);
  return errors != 0;
}
