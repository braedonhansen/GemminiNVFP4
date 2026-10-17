du -sh ~/.cache/coursier ~/.sbt 2>/dev/null
find ~ -maxdepth 6 -iname "*firtool*" -not -path "*/chipyard-mx/*" 2>/dev/null | head
find ~/.cache -maxdepth 3 | head -20
cat ~/chipyard-mx/project/build.properties; ls ~/.sbt/1.0 ~/.sbt/boot 2>&1| head
find ~/chipyard-mx/.conda-env -iname "firtool*" | head -3
ls ~/.cache/coursier/v1/https/repo1.maven.org/maven2/org/chipsalliance/chisel_2.13 ~/.cache/coursier/v1/https/repo1.maven.org/maven2/org/chipsalliance/chisel-plugin_2.13.16
