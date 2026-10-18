cd ~/chipyard-mx/generators/gemmini
git add src/main/scala/gemmini/AccumulatorMem.scala
git -c user.name="Braedonhansen" -c user.email="braedon.hansen@gmail.com" commit -q -F - <<'MSG'
NVFP4 AccumulatorMem: block mvout reads while the delayed accumulate read owns the SRAM read port

The accumulate's old-row read is issued 3 cycles after the write fires (NvFp4RmwPipe.rd_en), so the existing
"no read while a write accumulates" check (cycle of the write) no longer covers it. Found by running the M5 MX test
binary on the NVFP4 simulator: AsymmetricTwoPortSyncMem asserted "cannot read full and chunk simultaneously".

Co-Authored-By: Claude Opus 5.5 <noreply@anthropic.com>
MSG
git log --oneline -3
