cd ~/chipyard-mx
grep -q build-setup-conda env.sh || cat >> env.sh <<'EOT'


# >>> build-setup-conda initialize >>>
# added manually (build-setup step 1 skipped; conda env created by hand, as in M2)
if ! type conda >& /dev/null; then
    echo "::ERROR:: you must have conda in your environment first"
    return 1
fi

source $(conda info --base)/etc/profile.d/conda.sh
conda activate /home/braed/chipyard-mx/.conda-env
source /home/braed/chipyard-mx/scripts/fix-open-files.sh
# <<< build-setup-conda initialize <<<
EOT
source ~/miniforge3/etc/profile.d/conda.sh; source env.sh
echo RISCV=$RISCV; which riscv64-unknown-elf-gcc spike verilator; verilator --version
