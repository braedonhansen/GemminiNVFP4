// M7.P0 / P0.3: activity workload for the Cadence power flow. Stock INT8 Gemmini (upstream 8c3f9923, DIM=16,
// GemminiRocketConfig), 64x64x512 matmul through the stock library path (tiled_matmul_auto, weight-stationary),
// full-width INT32 output (same choice as M7.A), pseudo-random full-range int8 operands generated in the program (xorshift32),
// so the data are not zero/structured (power depends on the data).
//
// Check (against the CPU, after the kernel, so outside the measured window):
//   * default build:  Freivalds test on ALL 64x64 outputs (C*r == A*(B*r) exactly, r_j in 1..251, int64 arithmetic, so any
//                     single wrong element is detected) + 4 complete rows recomputed directly (4*64 outputs, K=512 each)
//   * -DM7P_FULL_REF: every one of the 4096 outputs recomputed directly (slow on Rocket; used once to validate the test)
//   * -DM7P_CORRUPT:  flips one output bit before the check; must FAIL (negative control)
// Exit code 0 only if >= 1 output was compared and none mismatched.
#include <stdint.h>
#include <stddef.h>
#include <stdio.h>
#include <string.h>
#include "include/gemmini_testutils.h"

#define MM 64
#define NN 64
#define KK 512
static elem_t A_buf[MM * KK] row_align(1);
static elem_t B_buf[KK * NN] row_align(1);
static acc_t C_buf[MM * NN] row_align(1);

// xorshift32: 4 independent-looking bytes per call (a power-of-two LCG has short-period low bytes)
static uint32_t rng_state = 20261021u;
static uint32_t rng(void) { uint32_t x = rng_state; x ^= x << 13; x ^= x >> 17; x ^= x << 5; rng_state = x; return x; }

int main() {
  gemmini_flush(0);
  for (int i = 0; i < MM * KK; i += 4) { uint32_t r = rng(); for (int b = 0; b < 4; ++b) A_buf[i + b] = (int8_t)(r >> (8 * b)); }
  for (int i = 0; i < KK * NN; i += 4) { uint32_t r = rng(); for (int b = 0; b < 4; ++b) B_buf[i + b] = (int8_t)(r >> (8 * b)); }
  for (int i = 0; i < MM * NN; ++i) C_buf[i] = 0x7eadbeef;   // poison
  printf("M7P kernel start\n");
  tiled_matmul_auto(MM, NN, KK, A_buf, B_buf, NULL, C_buf,
                    KK, NN, NN, NN,
                    MVIN_SCALE_IDENTITY, MVIN_SCALE_IDENTITY, MVIN_SCALE_IDENTITY,
                    NO_ACTIVATION, ACC_SCALE_IDENTITY, 0, false,
                    false, false,
                    true, false,   // full_C: INT32 output
                    0, WS);
  gemmini_fence();
  printf("M7P kernel end\n");
#ifdef M7P_CORRUPT
  C_buf[37 * NN + 11] ^= 1;
#endif
  long checked = 0, bad = 0;
#ifdef M7P_FULL_REF
  for (int i = 0; i < MM; ++i) {
    static int32_t row[NN];
    for (int j = 0; j < NN; ++j) row[j] = 0;
    for (int k = 0; k < KK; ++k) { int32_t a = A_buf[i * KK + k]; for (int j = 0; j < NN; ++j) row[j] += a * B_buf[k * NN + j]; }
    for (int j = 0; j < NN; ++j) { ++checked; if (row[j] != C_buf[i * NN + j]) { if (bad < 8) printf("C[%d][%d] got %d want %d\n", i, j, (int)C_buf[i * NN + j], (int)row[j]); ++bad; } }
  }
  printf("full reference: %ld outputs compared, %ld mismatches\n", checked, bad);
#else
  // 4 full rows, direct
  static const int rows[4] = {0, 21, 42, 63};
  for (int r = 0; r < 4; ++r) {
    int i = rows[r];
    for (int j = 0; j < NN; ++j) {
      int32_t s = 0;
      for (int k = 0; k < KK; ++k) s += (int32_t)A_buf[i * KK + k] * B_buf[k * NN + j];
      ++checked;
      if (s != C_buf[i * NN + j]) { if (bad < 8) printf("C[%d][%d] got %d want %d\n", i, j, (int)C_buf[i * NN + j], (int)s); ++bad; }
    }
  }
  // Freivalds over all outputs
  static int64_t br[KK];
  static int32_t rv[NN];
  for (int j = 0; j < NN; ++j) rv[j] = 1 + (int32_t)(rng() % 251);
  for (int k = 0; k < KK; ++k) { int64_t s = 0; for (int j = 0; j < NN; ++j) s += (int64_t)B_buf[k * NN + j] * rv[j]; br[k] = s; }
  long frows = 0, fbad = 0;
  for (int i = 0; i < MM; ++i) {
    int64_t lhs = 0, rhs = 0;
    for (int j = 0; j < NN; ++j) lhs += (int64_t)C_buf[i * NN + j] * rv[j];
    for (int k = 0; k < KK; ++k) rhs += (int64_t)A_buf[i * KK + k] * br[k];
    ++frows; if (lhs != rhs) ++fbad;
  }
  checked += frows * NN; bad += fbad;   // each Freivalds row covers its 64 outputs
  printf("direct rows: 4 rows (256 outputs); Freivalds: %ld rows (%ld outputs), %ld row mismatches; total mismatches %ld\n", frows, frows * NN, fbad, bad);
#endif
  printf("m7p_int8_64x64x512: %ld outputs checked, %ld bad\n", checked, bad);
  return (bad != 0 || checked == 0);
}
