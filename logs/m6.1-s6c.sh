du -sh ~/.cache/coursier 2>&1 | tail -1
~/chipyard-mx/.conda-env/riscv-tools/bin/firtool --version | head -3
mkdir -p ~/nvfp4-logs/m6.1-sbt
cp -r ~/.cache/coursier ~/nvfp4-logs/m6.1-sbt/coursier && du -sh ~/nvfp4-logs/m6.1-sbt/coursier
ls ~/.sbt/boot ~/.sbt/preloaded 2>&1 | head -3; ls ~/.cache/coursier/v1/https/repo1.maven.org/maven2/org/scala-sbt/sbt 2>&1 | head
