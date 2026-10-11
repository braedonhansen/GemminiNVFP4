for i in $(seq 1 60); do wsl -d Ubuntu-22.04 -- bash -c 'test -f ~/nvfp4-logs/m4-verilator.done' && break; sleep 90; done
wsl -d Ubuntu-22.04 -- bash -c 'cat ~/nvfp4-logs/m4-verilator.done; tail -15 ~/nvfp4-logs/m4-verilator.log'
