p='/home/braed/chipyard-mx/generators/gemmini/src/main/scala/gemmini/Scratchpad.scala'
s=open(p).read()
def rep(old,new,cnt=1):
    global s
    assert s.count(old)==cnt, (old, s.count(old))
    s=s.replace(old,new)
rep("""    val acc_adders = Module(new AccPipeShared(acc_latency-1, acc_row_t, acc_banks))
""","""    // NVFP4: the accumulate adder (2-stage FP32) lives inside each AccumulatorMem's NvFp4RmwPipe; no shared MX adder.
    val acc_adders = Option.when(!config.use_nvfp4)(Module(new AccPipeShared(acc_latency-1, acc_row_t, acc_banks)))
""")
rep("""        meshRows,
        tileRows,
      )) }
      val bank_ios""","""        meshRows,
        tileRows,
        config.use_nvfp4,
      )) }
      val bank_ios""")
rep("""          meshRows = meshRows,
          tileRows = tileRows
        ))
        Seq((sm.io.scale_mem_write_w""","""          meshRows = meshRows,
          tileRows = tileRows,
          scaleSize = config.scaleSize,
          nvfp4 = config.use_nvfp4
        ))
        Seq((sm.io.scale_mem_write_w""")
rep("""        acc_adders.io.in_sel(i) := bio.adder.valid
        acc_adders.io.ina(i) := bio.adder.op1
        acc_adders.io.inb(i) := bio.adder.op2
        bio.adder.sum := acc_adders.io.out""","""        acc_adders match {
          case Some(adders) =>
            adders.io.in_sel(i) := bio.adder.valid
            adders.io.ina(i) := bio.adder.op1
            adders.io.inb(i) := bio.adder.op2
            bio.adder.sum := adders.io.out
          case None =>
            bio.adder.sum := DontCare
        }""")
open(p,'w').write(s)
print("ok")
