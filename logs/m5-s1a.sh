mkdir -p ~/nvfp4-logs
cd ~
if [ ! -d chipyard-mx/.git ]; then git clone --reference ~/chipyard https://github.com/ucb-bar/chipyard.git chipyard-mx > ~/nvfp4-logs/m5-clone.log 2>&1; fi
cd chipyard-mx && git checkout 1.14.0 2>&1 | tail -1; git describe --tags; git rev-parse HEAD
