p='/home/braed/chipyard-mx/generators/gemmini/src/main/scala/gemmini/AccumulatorMem.scala'
s=open(p).read()
old="    mem.io.wen := oldest_pipelined_write.valid\n"
assert s.count(old)==1
nl=chr(92)+'n'
s=s.replace(old, old+'    if (use_nvfp4) { when(nvpipe.get.io.wr_valid) { printf("NVACC %x %x'+nl+'", nvpipe.get.io.wr_addr, nvpipe.get.io.wr_data.asUInt) } } // TEMP DEBUG\n')
open(p,'w').write(s)
