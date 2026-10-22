source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null 2>&1
python3 /mnt/c/Users/braed/gemmini-nvfp4/logs/m7p-p01.py ~/nvfp4-logs/m7p/int8 2>&1 | tee ~/nvfp4-logs/m7p/p01.log
