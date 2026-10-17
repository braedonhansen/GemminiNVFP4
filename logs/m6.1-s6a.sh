export PATH=~/chipyard-mx/.conda-env/bin:$PATH
which java sbt firtool verilator; java -version 2>&1 | head -1; sbt --version 2>&1 | tail -2; firtool --version 2>&1 | head -2; verilator --version
ls ~/.cache/coursier/v1/https/repo1.maven.org/maven2/org/chipsalliance 2>&1 | head; find ~/.cache/coursier -maxdepth 8 -iname "*chisel_2.13*" | head; find ~/.cache -iname "firtool*" | head -3
grep -rn "chisel\|scalaVersion" ~/chipyard-mx/build.sbt | head -10
ls ~/.sbt ~/.ivy2 2>&1 | head -3
