// Functional test of a generated 1W+1R wrapper vs a behavioural reference (M7.P0b).
// Defines: DUT, AW, W, MG (0 = no mask port), NCYC
`timescale 1ns/1ps
module tb;
  localparam HASM = (`MG != 0);
  localparam NM = HASM ? (`W / (`MG ? `MG : 1)) : 1;
  reg clk = 0;
  reg [`AW-1:0] waddr, raddr; reg wen, ren; reg [`W-1:0] wdata; reg [NM-1:0] wmask;
  wire [`W-1:0] rdata;
`ifdef HAS_MASK
    `DUT dut(.R0_addr(raddr), .R0_clk(clk), .R0_data(rdata), .R0_en(ren),
             .W0_addr(waddr), .W0_clk(clk), .W0_data(wdata), .W0_en(wen), .W0_mask(wmask));
`else
    `DUT dut(.R0_addr(raddr), .R0_clk(clk), .R0_data(rdata), .R0_en(ren),
             .W0_addr(waddr), .W0_clk(clk), .W0_data(wdata), .W0_en(wen));
`endif
  reg [`W-1:0] ref_mem [0:(1<<`AW)-1];
  reg [`W-1:0] exp_rd; reg exp_valid;
  integer cyc, checks, errs, writes, reads, i;
  reg [`W-1:0] tmp;
  always #5 clk = ~clk;
  initial begin
    checks = 0; errs = 0; writes = 0; reads = 0; exp_valid = 0; wen = 0; ren = 0; waddr = 0; raddr = 0; wdata = 0; wmask = {NM{1'b1}};
    for (i = 0; i < (1<<`AW); i = i + 1) ref_mem[i] = 0;
    for (i = 0; i < (1<<`AW); i = i + 1) begin
      @(negedge clk); wen = 1; ren = 0; waddr = i; wdata = {`W{1'b0}}; wmask = {NM{1'b1}};
    end
    for (cyc = 0; cyc < `NCYC; cyc = cyc + 1) begin
      @(negedge clk);
      wen = ($urandom % 3) != 0; ren = ($urandom % 3) != 0; waddr = $urandom; raddr = $urandom;
      if (raddr == waddr) raddr = raddr ^ 1;   // same-address read/write in one cycle is undefined for the macro
      for (i = 0; i < `W/32; i = i + 1) wdata[i*32 +: 32] = $urandom;
      for (i = 0; i < NM; i = i + 1) wmask[i] = HASM ? ($urandom % 2) : 1'b1;
      #4;   // 1 ns before the posedge: the previous read must have settled
      if (exp_valid) begin
        checks = checks + 1;
        if (rdata !== exp_rd) begin errs = errs + 1; if (errs < 5) $display("MISMATCH cyc %0d exp %h got %h", cyc, exp_rd, rdata); end
      end
      exp_valid = 0;
      @(posedge clk); #1;
      if (ren) begin exp_rd = ref_mem[raddr]; exp_valid = 1; reads = reads + 1; end
      if (wen) begin
        tmp = ref_mem[waddr];
        if (HASM) begin for (i = 0; i < NM; i = i + 1) if (wmask[i]) tmp[i*(`MG ? `MG : 1) +: (`MG ? `MG : 1)] = wdata[i*(`MG ? `MG : 1) +: (`MG ? `MG : 1)]; end
        else tmp = wdata;
        ref_mem[waddr] = tmp; writes = writes + 1;
      end
    end
    @(negedge clk); #4;   // final check, 1 ns before the next posedge
    if (exp_valid) begin checks = checks + 1; if (rdata !== exp_rd) errs = errs + 1; end
    $display("TB_RESULT dut=%s checks=%0d reads=%0d writes=%0d errors=%0d", `DUTNAME, checks, reads, writes, errs);
    $finish;
  end
endmodule
