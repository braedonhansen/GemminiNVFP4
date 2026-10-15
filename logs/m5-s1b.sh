source ~/miniforge3/etc/profile.d/conda.sh
conda activate base
cd ~/chipyard-mx
date +%s > ~/nvfp4-logs/m5-step1.start
conda create -y -p $PWD/.conda-lock-env -c conda-forge python=3.11 conda-lock=2.5.7 || { echo 1 > ~/nvfp4-logs/m5-step1.done; exit 1; }
conda activate $PWD/.conda-lock-env
conda-lock install --conda $CONDA_EXE -p $PWD/.conda-env conda-reqs/conda-lock-reqs/conda-requirements-riscv-tools-linux-64.conda-lock.yml || { echo 2 > ~/nvfp4-logs/m5-step1.done; exit 2; }
conda activate $PWD/.conda-env
./build-setup.sh riscv-tools -s 1 -s 6 -s 7 -s 8 -s 9
echo $? > ~/nvfp4-logs/m5-step1.done
date +%s > ~/nvfp4-logs/m5-step1.end
