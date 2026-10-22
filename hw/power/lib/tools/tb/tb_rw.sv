// Functional test of a generated 1RW wrapper vs a behavioural reference (M7.P0b).
// Defines: DUT (module), AW, W (data bits), MG (mask granularity bits), NCYC
`timescale 1ns/1ps
module tb;
  localparam NM = `W / `MG;
  reg clk = 0;
  reg [`AW-1:0] addr; reg en, wmode; reg [`W-1:0] wdata; reg [NM-1:0] wmask;
  wire [`W-1:0] rdata;
  `DUT dut(.RW0_addr(addr), .RW0_clk(clk), .RW0_wdata(wdata), .RW0_rdata(rdata),
           .RW0_en(en), .RW0_wmode(wmode), .RW0_wmask(wmask));
  reg [`W-1:0] ref_mem [0:(1<<`AW)-1];
  reg [`W-1:0] exp_rd; reg exp_valid;
  integer cyc, checks, errs, writes, reads, i;
  reg [`W-1:0] tmp;
  always #5 clk = ~clk;
  initial begin
    checks = 0; errs = 0; writes = 0; reads = 0; exp_valid = 0; en = 0; wmode = 0; addr = 0; wdata = 0; wmask = 0;
    for (i = 0; i < (1<<`AW); i = i + 1) ref_mem[i] = 0;
    // initialise whole array through the wrapper (full mask writes) so reads are never X
    for (i = 0; i < (1<<`AW); i = i + 1) begin
      @(negedge clk); en = 1; wmode = 1; addr = i; wdata = {`W{1'b0}}; wmask = {NM{1'b1}};
    end
    for (cyc = 0; cyc < `NCYC; cyc = cyc + 1) begin
      @(negedge clk);
      en = ($urandom % 4) != 0; wmode = $urandom % 2; addr = $urandom;
      for (i = 0; i < `W/32; i = i + 1) wdata[i*32 +: 32] = $urandom;
      for (i = 0; i < NM; i = i + 1) wmask[i] = $urandom % 2;
      #4;   // 1 ns before the posedge: the previous read must have settled
      if (exp_valid) begin
        checks = checks + 1;
        if (rdata !== exp_rd) begin errs = errs + 1; if (errs < 5) $display("MISMATCH cyc %0d exp %h got %h", cyc, exp_rd, rdata); end
      end
      exp_valid = 0;
      @(posedge clk); #1;
      if (en && !wmode) begin exp_rd = ref_mem[addr]; exp_valid = 1; reads = reads + 1; end
      if (en && wmode) begin
        tmp = ref_mem[addr];
        for (i = 0; i < NM; i = i + 1) if (wmask[i]) tmp[i*`MG +: `MG] = wdata[i*`MG +: `MG];
        ref_mem[addr] = tmp; writes = writes + 1;
      end
    end
    @(negedge clk); #4;   // final check, 1 ns before the next posedge
    if (exp_valid) begin checks = checks + 1; if (rdata !== exp_rd) errs = errs + 1; end
    $display("TB_RESULT dut=%s checks=%0d reads=%0d writes=%0d errors=%0d", `DUTNAME, checks, reads, writes, errs);
    $finish;
  end
endmodule
