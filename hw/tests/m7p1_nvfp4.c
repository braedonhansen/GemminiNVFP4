// M7.P1 / nvfp4-a: our NVFP4 Gemmini (~/chipyard-mx branch nvfp4, NvFp4GemminiRocketConfig), the COMMON workload: M=64 N=64 K=512,
// A and B = Gaussian make_inputs(seed 20261030) quantised with the NVFP4 refmodel recipe (E2M1 values, E4M3 block scale per 16 K, FP32 tensor
// scale), FP32 output, checked BIT FOR BIT against refmodel hw_dot.hw_matmul_v0 (the M6/M7.A bit-exact model). Software = the branch's own
// path from hw/tests/nvfp4_e2e_mnk.c (kept line for line): MX_LOAD_SCALES, quad-layout mvins, gemmini_loop_ws_spad, tensor scale via acc_scale at
// mvout, FP32 rows read back from the scratchpad. Only the kernel markers, the control variant and the exact output count are new.
//   -DM7P1_CTL: control, flips one output bit before the check; it must FAIL (exit 1, 1 mismatch).
#include <stdint.h>
#include <stdio.h>
#include <string.h>
#include "include/gemmini_testutils.h"
#include "m7p1_nvfp4_data.h"

#define DIM 16
#define TILES_I (E2E_M / DIM / 2)
#define TILES_J (E2E_N / DIM / 2)
#define TILES_K (E2E_K / DIM)
#define SPAD_ROWS (BANK_NUM * BANK_ROWS)
#define A_ROWS (TILES_I * TILES_K * DIM)
#define B_ROWS (TILES_K * TILES_J * DIM)
#define C_ROWS (E2E_M * E2E_N * 4 / DIM)
#define SPAD_DEST BANK_ROWS
_Static_assert(E2E_M == 64 && E2E_N == 64 && E2E_K == 512, "the common workload is 64x64x512");
_Static_assert(A_ROWS <= SPAD_DEST, "A region must end below the output region");
_Static_assert(SPAD_DEST + C_ROWS <= SPAD_ROWS - B_ROWS, "output region must end below the B region");
_Static_assert(TILES_I * TILES_J * DIM <= ACC_ROWS, "accumulator rows needed exceed ACC_ROWS");
_Static_assert((E2E_K / 16) * E2E_M <= 4096 && (E2E_K / 16) * E2E_N <= 4096, "scale bytes per operand exceed the 4096-byte window");

static inline uint32_t f2u(float f) { uint32_t u; memcpy(&u, &f, sizeof u); return u; }

int main() {
  static uint32_t C_hw[E2E_M][E2E_N] __attribute__((aligned(64)));
  uint32_t scale_factors[512] __attribute__((aligned(32))) = {0};
  memset(C_hw, 0xa5, sizeof(C_hw));

  const int tiles_I = TILES_I, tiles_J = TILES_J, tiles_K = TILES_K;
  const uint32_t a_base = 0;
  const uint32_t b_base = BANK_NUM * BANK_ROWS - tiles_K * tiles_J * DIM;

  // the tensor-scale factor in the refmodel's float32 order: (tA*tB)*0.25f, each op one IEEE RNE op
  volatile float fac = tA * tB;
  fac = fac * 0.25f;
  float factor = fac;

  gemmini_flush(0);
  printf("M7P kernel start\n");
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

  gemmini_extended_config_st(DIM * sizeof(uint32_t), NO_ACTIVATION, factor);
  gemmini_mxquant_config_mvout((uint64_t)scale_factors, tiles_I, tiles_J, tiles_K, 0, 0, 1);
  gemmini_loop_ws_spad(tiles_I, tiles_J, tiles_K, 0, 0, 0, a_base, BANK_NUM * BANK_ROWS, 0, SPAD_DEST,
                       false, false, false, false, false, NO_ACTIVATION, 0, 0, false, 0x38);
  gemmini_fence();

  gemmini_config_st(DIM * sizeof(uint8_t));
  const int total_spad_rows = E2E_M * E2E_N * (int)sizeof(uint32_t) / DIM;
  uint8_t *c_base = (uint8_t *)C_hw;
  for (int r = 0; r < total_spad_rows; r += DIM)
    gemmini_extended_mvout(c_base + r * DIM, SPAD_DEST + r, DIM, DIM);
  gemmini_fence();
  printf("M7P kernel end\n");
#ifdef M7P1_CTL
  C_hw[37][11] ^= 1;
#endif
  long checked = 0, bad = 0;
  for (int i = 0; i < E2E_M; i++)
    for (int j = 0; j < E2E_N; j++) {
      ++checked;
      if (C_hw[i][j] != out_bits[i][j]) {
        if (bad < 8) printf("MISMATCH out[%d][%d]: got 0x%08x want 0x%08x\n", i, j, (unsigned)C_hw[i][j], (unsigned)out_bits[i][j]);
        ++bad;
      }
    }
  printf("factor bits 0x%08x\n", (unsigned)f2u(factor));
  printf("m7p1_nvfp4_64x64x512: %ld outputs checked, %ld bad\n", checked, bad);
  return (bad != 0 || checked != 64 * 64);
}
