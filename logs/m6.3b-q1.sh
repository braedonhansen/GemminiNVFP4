cd ~/chipyard-mx
sed -n 100,175p generators/gemmini/chipyard/GemminiConfigs.scala
ls -la generators/chipyard/src/main/scala/config/ | grep -i gemmini
ls -la generators/chipyard/src/main/scala/config/GemminiConfigs.scala
git -C generators/gemmini status --short | head
