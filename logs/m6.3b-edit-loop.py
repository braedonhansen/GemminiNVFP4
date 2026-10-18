base='/home/braed/chipyard-mx/generators/gemmini/src/main/scala/gemmini/'
def edit(fn, pairs):
    s=open(base+fn).read()
    for old,new in pairs:
        assert s.count(old)==1,(fn,old,s.count(old))
        s=s.replace(old,new)
    open(base+fn,'w').write(s)
edit('LoopMatmul.scala',[
("""                 vec_bypass: Boolean = false)
                (implicit p: Parameters) extends Module {
  val iterator_bitwidth = 16
  val tilesPerMxBlock = 32 / block_size""","""                 vec_bypass: Boolean = false, scale_size: Int = 32)
                (implicit p: Parameters) extends Module {
  val iterator_bitwidth = 16
  // k-tiles per scale block: scale_size / DIM (MX: 32/16 = 2; NVFP4: scaleSize 16 -> 1)
  val tilesPerMxBlock = scale_size / block_size"""),
("""            vec_bypass: Boolean = false)
           (implicit p: Parameters): (DecoupledIO[GemminiCmd], Bool, Vec[Bool], LoopMatmul) = {""","""            vec_bypass: Boolean = false, scale_size: Int = 32)
           (implicit p: Parameters): (DecoupledIO[GemminiCmd], Bool, Vec[Bool], LoopMatmul) = {"""),
("""mvout_spad_rs1_t, mvout_rs2_t, vec_bypass))
    mod.io.in <> in""","""mvout_spad_rs1_t, mvout_rs2_t, vec_bypass, scale_size))
    mod.io.in <> in"""),
])
edit('Controller.scala',[
("""    vec_bypass = has_vpu || has_spad_requant) }
  
  if (use_mx_scaling) {""","""    vec_bypass = has_vpu || has_spad_requant, scale_size = scaleSize) }
  
  if (use_mx_scaling) {"""),
])
print("ok")
