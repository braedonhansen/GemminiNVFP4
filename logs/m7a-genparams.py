"""Python port of GemminiArrayConfig.generateHeader (generators/gemmini/src/main/scala/gemmini/GemminiConfigs.scala, 8c3f9923)
for the two configs M7.A needs: the stock INT8 default (used to VALIDATE the port by diffing against the real
gemmini_params.h in ~/chipyard) and GemminiFPConfigs.FP32DefaultConfig (whose real header would otherwise only exist
after elaborating FPGemminiRocketConfig, which writes into the tree). Run: python3 m7a-genparams.py int8|fp32 > out.h"""
import sys

def header(kind):
    fp = kind == "fp32"
    DIM = 4 if fp else 16
    sp_banks = 4
    sp_bank_entries = 4096                      # 256 KiB / (4 banks * DIM*width/8 bytes) for both
    acc_rows = 4096 if fp else 1024             # FP32: 64 KiB / (1 bank * 4 * 32 bit); INT8: 64 KiB / (1 * 16 * 32)... (see check)
    h = []
    a = h.append
    a("#ifndef GEMMINI_PARAMS_H\n#define GEMMINI_PARAMS_H\n\n#include <stdint.h>\n#include <limits.h>\n\n")
    a("#define XCUSTOM_ACC 3\n")
    a(f"#define DIM {DIM}\n#define ADDR_LEN 32\n#define BANK_NUM {sp_banks}\n#define BANK_ROWS {sp_bank_entries}\n#define ACC_ROWS {acc_rows}\n")
    a("#define MAX_BYTES 64\n")
    a(f"#define MAX_BLOCK_LEN (MAX_BYTES/(DIM*{4 if fp else 1}))\n")
    a("#define MAX_BLOCK_LEN_ACC (MAX_BYTES/(DIM*4))\n\n")
    if fp:
        a("typedef float elem_t;\nstatic const elem_t elem_t_max = 3.4028235E38;\nstatic const elem_t elem_t_min = -3.4028235E38;\ntypedef float acc_t;\ntypedef double full_t;\n\n")
        a("#define ELEM_T_IS_FLOAT\n#define ELEM_T_EXP_BITS 8\n#define ELEM_T_SIG_BITS 24\n#define ACC_T_EXP_BITS 8\n#define ACC_T_SIG_BITS 24\ntypedef uint32_t elem_t_bits;\ntypedef uint32_t acc_t_bits;\n\n")
        a("#define HAS_MVIN_SCALE\ntypedef float scale_t;\ntypedef uint32_t scale_t_bits;\n\n")
        a("#define HAS_MVIN_ACC_SCALE\ntypedef float scale_acc_t;\ntypedef uint32_t scale_acc_t_bits;\n\n")
    else:
        a("typedef int8_t elem_t;\nstatic const elem_t elem_t_max = 127;\nstatic const elem_t elem_t_min = -128;\ntypedef int32_t acc_t;\ntypedef int64_t full_t;\n\n")
        a("#define HAS_MVIN_SCALE\ntypedef float scale_t;\ntypedef uint32_t scale_t_bits;\n\n")
        a("typedef int32_t scale_acc_t;\ntypedef uint32_t scale_acc_t_bits;\n\n")
    a("typedef float acc_scale_t;\ntypedef uint32_t acc_scale_t_bits;\n\n")
    a("#define row_align(blocks) __attribute__((aligned(blocks*DIM*sizeof(elem_t))))\n#define row_align_acc(blocks) __attribute__((aligned(blocks*DIM*sizeof(acc_t))))\n\n")
    a("#define MVIN_SCALE_IDENTITY 1.0\n\n#define ACC_SCALE_IDENTITY 1.0\n\n")
    if fp:
        a("#define ROUNDING_RIGHT_SHIFT(x, shift) \\\n    ((x) / (1 << (shift)))\n\n")
    else:
        a("// Rounding right shift equation: https://riscv.github.io/documents/riscv-v-spec/#_vector_fixed_point_rounding_mode_register_vxrm\n#define ROUNDING_RIGHT_SHIFT(x, shift) \\\n    ((shift) > 0 ? (((x) >> (shift)) + \\\n        (((shift) == 0 ? 0 : (((x) >> ((shift)-1)) & 1)) & \\\n             ((((shift) <= 1 ? 0 : ((x) & ((1 << ((shift)-1)) - 1))) != 0) | (((x) >> (shift)) & 1)))) : ((x) << (-(shift))))\n\n")
    a("#ifdef __cplusplus\n#define SAME_TYPE(x) decltype(x)\n#else\n#define SAME_TYPE(x) typeof(x)\n#endif\n\n")
    a("#define ROUND_NEAR_EVEN(x) \\\n    ({ const SAME_TYPE(x) x_ = (x); \\\n         const long long i = x_; \\\n         const long long next = x_ < 0 ? x_ - 1 : x_ + 1; \\\n         SAME_TYPE(x) rem = x_ - i; \\\n         rem = rem < 0 ? -rem : rem; \\\n         SAME_TYPE(x) result = rem < 0.5 ? i : (rem > 0.5 ? next : ( \\\n                     i % 2 == 0 ? i : next)); \\\n         result; })\n\n")
    a("// Rounding right shift equation: https://riscv.github.io/documents/riscv-v-spec/#_vector_fixed_point_rounding_mode_register_vxrm\n#define ROUNDING_RIGHT_SHIFT_BITS(x, shift) \\\n((shift) > 0 ? (((x) >> (shift)) + \\\n    (((shift) == 0 ? 0 : (((x) >> ((shift)-1)) & 1)) & \\\n         ((((shift) <= 1 ? 0 : ((x) & ((1 << ((shift)-1)) - 1))) != 0) | (((x) >> (shift)) & 1)))) : ((x) << (-(shift))))\n\n")
    if fp:
        a("#define ACC_SCALE(x, scale) \\\n    ((x) * (scale))\n\n")
        a("#define MVIN_SCALE(x, scale) \\\n    ((x) * (scale))\n\n")
        a("#define MVIN_SCALE_ACC(x, scale) \\\n    ((x) * (scale))\n\n")
    else:
        a("#define ACC_SCALE(x, scale) \\\n    ({float y = ROUND_NEAR_EVEN((x) * (scale)); y > INT8_MAX ? INT8_MAX : (y < INT8_MIN ? INT8_MIN : (acc_t)y);})\n\n")
        a("#define MVIN_SCALE(x, scale) \\\n    ({float y = ROUND_NEAR_EVEN((x) * (scale)); y > INT8_MAX ? INT8_MAX : (y < INT8_MIN ? INT8_MIN : (elem_t)y);})\n\n")
        a("#define MVIN_SCALE_ACC(x, scale) (x)\n\n")
    a("#define ACC_SCALE_T_IS_FLOAT\n#define ACC_SCALE_EXP_BITS 8\n#define ACC_SCALE_SIG_BITS 24\n\n")
    a("#define ACC_READ_SMALL_WIDTH\n#define ACC_READ_FULL_WIDTH\n\n#define HAS_FIRST_LAYER_OPTIMIZATIONS\n\n#endif // GEMMINI_PARAMS_H\n")
    return "".join(h)

if __name__ == "__main__":
    sys.stdout.buffer.write(header(sys.argv[1]).encode())
