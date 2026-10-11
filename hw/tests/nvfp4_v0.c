// M4 v0: NVFP4 matmul with the integer part on stock Gemmini and the scales on the CPU.
//
// For each K block (16 wide): mvin A's decoded int8 block and B's decoded int8 block,
// preload B (weight-stationary), compute, and read the full int32 accumulator rows back
// (full-width mvout, not the clipped int8 path). Then, in float32 on the CPU:
//   blk = ((float)isum * sA[i][kb]) * sB[kb][j];   acc += blk (kb ascending);
//   out = acc * ((tA * tB) * 0.25f)
// Check 1: every int32 block sum equals the reference. Check 2: out bits equal the reference.
// Exits nonzero on any mismatch.

#include <stdint.h>
#include <stddef.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include "include/gemmini_testutils.h"
#include "nvfp4_v0_data.h"

#ifndef ACC_READ_FULL_WIDTH
#error this test needs full-width accumulator reads
#endif

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

// The Makefile builds with -ffast-math (and GCC may fuse multiply-add), so every float32
// intermediate goes through a volatile to force one correctly rounded IEEE operation each.
static float scale_case(int32_t isum, float sa, float sb, volatile float *acc) {
  volatile float t = (float)isum;
  t = t * sa;
  t = t * sb;
  volatile float s = *acc + t;
  *acc = s;
  return s;
}

static elem_t A_buf[NVFP4_MAX_NB][DIM][DIM] row_align(1);
static elem_t B_buf[NVFP4_MAX_NB][DIM][DIM] row_align(1);
static acc_t C_buf[NVFP4_MAX_NB][DIM][DIM] row_align_acc(1);

int main() {
  gemmini_flush(0);

  int bad_sums = 0, bad_out = 0, total_sums = 0, total_out = 0;
  uint64_t gem_cycles[NVFP4_NCASES] = {0};

  for (int c = 0; c < NVFP4_NCASES; ++c) {
    const nvfp4_case_t *tc = &nvfp4_cases[c];
    const int nb = tc->nb;

    for (int kb = 0; kb < nb; ++kb)
      for (int r = 0; r < DIM; ++r)
        for (int s = 0; s < DIM; ++s) {
          A_buf[kb][r][s] = tc->A[kb][r][s];
          B_buf[kb][r][s] = tc->B[kb][r][s];
          C_buf[kb][r][s] = 0x7eadbeef;  // poison, to catch rows that are never written
        }

    const uint32_t A_addr = 0;
    const uint32_t B_addr = NVFP4_MAX_NB * DIM;
    const uint32_t C_acc = 1u << (ADDR_LEN - 1);                          // overwrite, no accumulate
    const uint32_t C_out = (1u << (ADDR_LEN - 1)) | (1u << (ADDR_LEN - 3));  // read full width

    uint64_t t0 = rdcycle();
    gemmini_config_ld(DIM * sizeof(elem_t));
    gemmini_config_ex(WEIGHT_STATIONARY, NO_ACTIVATION, 0);
    gemmini_config_st(DIM * sizeof(acc_t));

    for (int kb = 0; kb < nb; ++kb) {
      gemmini_mvin(A_buf[kb], A_addr + kb * DIM);
      gemmini_mvin(B_buf[kb], B_addr + kb * DIM);
    }
    for (int kb = 0; kb < nb; ++kb) {
      gemmini_preload(B_addr + kb * DIM, C_acc + kb * DIM);
      gemmini_compute_preloaded(A_addr + kb * DIM, GARBAGE_ADDR);
    }
    for (int kb = 0; kb < nb; ++kb)
      gemmini_mvout(C_buf[kb], C_out + kb * DIM);
    gemmini_fence();
    gem_cycles[c] = rdcycle() - t0;

    // Check 1: integer block sums
    for (int kb = 0; kb < nb; ++kb)
      for (int i = 0; i < DIM; ++i)
        for (int j = 0; j < DIM; ++j) {
          ++total_sums;
          if (C_buf[kb][i][j] != tc->isum[kb][i][j]) {
            if (bad_sums < 8)
              printf("case %d kb %d [%d][%d]: isum got %d want %d\n", c, kb, i, j,
                     (int)C_buf[kb][i][j], (int)tc->isum[kb][i][j]);
            ++bad_sums;
          }
        }

    // Check 2: float32 output, bit-exact
    volatile float ts = tc->tA * tc->tB;
    ts = ts * 0.25f;
    for (int i = 0; i < DIM; ++i)
      for (int j = 0; j < DIM; ++j) {
        volatile float acc = 0.0f;
        for (int kb = 0; kb < nb; ++kb)
          scale_case(C_buf[kb][i][j], tc->sA[i][kb], tc->sB[kb][j], &acc);
        volatile float o = acc * ts;
        float out = o;
        ++total_out;
        if (f2u(out) != tc->out_bits[i][j]) {
          if (bad_out < 8)
            printf("case %d out[%d][%d]: got 0x%08x want 0x%08x\n", c, i, j,
                   (unsigned)f2u(out), (unsigned)tc->out_bits[i][j]);
          ++bad_out;
        }
      }

    printf("case %d (K=%d): gemmini cycles %lu\n", c, 16 * nb, (unsigned long)gem_cycles[c]);
  }

  printf("check1 (int32 block sums): %d mismatches of %d\n", bad_sums, total_sums);
  printf("check2 (float32 output bits): %d mismatches of %d\n", bad_out, total_out);
  exit((bad_sums || bad_out) ? 1 : 0);
}
