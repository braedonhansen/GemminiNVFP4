source ~/miniforge3/etc/profile.d/conda.sh
conda create -y -n eda -c conda-forge yosys iverilog > ~/nvfp4-logs/m6.1-env.log 2>&1
conda activate eda
yosys -V; iverilog -V | head -1
