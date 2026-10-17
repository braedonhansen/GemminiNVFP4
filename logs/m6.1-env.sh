# source this: sbt/java/verilator from chipyard-mx (read-only use), caches in ~/nvfp4-logs/m6.1-sbt
export PATH=$HOME/chipyard-mx/.conda-env/bin:$PATH
export CHISEL_FIRTOOL_PATH=$HOME/chipyard-mx/.conda-env/riscv-tools/bin
export COURSIER_CACHE=$HOME/nvfp4-logs/m6.1-sbt/coursier
export SBT_OPTS="-Dsbt.boot.directory=$HOME/nvfp4-logs/m6.1-sbt/boot -Dsbt.global.base=$HOME/nvfp4-logs/m6.1-sbt/global -Dsbt.ivy.home=$HOME/nvfp4-logs/m6.1-sbt/ivy -Dsbt.coursier.home=$HOME/nvfp4-logs/m6.1-sbt/coursier -Xmx3g"
