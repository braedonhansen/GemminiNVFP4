# M7.P1 design table. Source it, then `m7p1_design <job>`; sets the variables below. WSL only.
#   JOB      job name                       TREE     Chipyard tree the RTL is elaborated in (or read from)
#   CFG      Chipyard config                WRAP     wrappers/<design> folder
#   TEST     test source (hw/tests/<TEST>.c) PARAMS   gemmini_params.h for the test build ("tree" = the tree's own include dir)
#   W        job working directory (rtl, sim, test, runs, act, jobs)
#   RISCV_TREE the tree whose env.sh / toolchain / rocc-tests the build uses
R=/mnt/c/Users/braed/gemmini-nvfp4
M1=$HOME/nvfp4-logs/m7p1
m7p1_design() {
  JOB=$1
  case $JOB in
    int8-stock-b)  TREE=$HOME/chipyard;    CFG=GemminiRocketConfig;             WRAP=int8;  TEST=m7p1_int8;   PARAMS=tree ;;
    fp32-stock-a)  TREE=$M1/cy-stock;      CFG=FPGemminiRocketConfig;           WRAP=fp32;  TEST=m7p1_fp32;   PARAMS=$M1/fp32-stock-a/gemmini_params.h ;;
    nvfp4-a)       TREE=$HOME/chipyard-mx; CFG=NvFp4GemminiRocketConfig;        WRAP=nvfp4; TEST=m7p1_nvfp4;  PARAMS=$HOME/chipyard-mx/generators/gemmini/software/gemmini-rocc-tests/include/gemmini_params_nvfp4.h ;;
    mxfp4-a)       TREE=$M1/cy-mxbase;     CFG=MxFp4OnlyGemminiRocketConfig;    WRAP=mxfp4; TEST=m7p1_mxfp4;  PARAMS=$M1/mxfp4-a/gemmini_params.h ;;
    mxfp8-a)       TREE=$M1/cy-mxbase;     CFG=MxE4M3OnlyGemminiRocketConfig;   WRAP=mxfp8; TEST=m7p1_mxfp8;  PARAMS=$M1/mxfp8-a/gemmini_params.h ;;
    *) echo "unknown job $JOB"; return 1 ;;
  esac
  W=$M1/$JOB
  GEN=$TREE/sims/verilator/generated-src/chipyard.harness.TestHarness.$CFG
  RT=$TREE/generators/gemmini/software/gemmini-rocc-tests
  mkdir -p $W
}
# shell of a tree: m7p1_shell <tree>
m7p1_shell() {
  source ~/miniforge3/etc/profile.d/conda.sh
  cd $1; source env.sh >/dev/null 2>&1
}
m7p1_step() {  # m7p1_step <step> <PASS|FAIL> <evidence...>  -> repo step log
  echo "$(date -Iseconds) | $1 | $2 | ${*:3}" >> $R/logs/m7p1.steps
  echo "STEP $1 $2 ${*:3}"
}
