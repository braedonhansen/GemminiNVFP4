# Pass 2: rerun the same binary with the waveform window from pass 1 (cycles in Gemmini clock cycles); stops shortly after the window ends.
source ~/miniforge3/etc/profile.d/conda.sh; cd ~/chipyard; source env.sh >/dev/null 2>&1
W=$HOME/nvfp4-logs/m7p/act
S=$(grep ^start_cycle $W/window.txt | cut -d= -f2); E=$(grep ^end_cycle $W/window.txt | cut -d= -f2)
[ -n "$S" ] && [ -n "$E" ] || { echo "no window"; exit 2; }
MAXC=60000000   # the monitor ends the run itself at the window end ($finish)
echo "window $S..$E max-cycles(base clock)=$MAXC"
bash /mnt/c/Users/braed/gemmini-nvfp4/logs/m7p-sim-run.sh "~/nvfp4-logs/m7p/test/bin/m7p_int8_base" pass2 +m7p-start=$S +m7p-end=$E +vcdfile=$W/kernel.vcd
ls -la $W
