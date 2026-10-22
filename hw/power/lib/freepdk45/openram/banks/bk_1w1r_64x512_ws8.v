// OpenRAM SRAM model
// Words: 64
// Word size: 512
// Write size: 8

module bk_1w1r_64x512_ws8(
`ifdef USE_POWER_PINS
    vdd,
    gnd,
`endif
// Port 0: W
    clk0,csb0,wmask0,addr0,din0,
// Port 1: R
    clk1,csb1,addr1,dout1
  );

  parameter NUM_WMASKS = 64 ;
  parameter DATA_WIDTH = 512 ;
  parameter ADDR_WIDTH = 6 ;
  parameter RAM_DEPTH = 1 << ADDR_WIDTH;
  // FIXME: This delay is arbitrary.
  parameter DELAY = 3 ;
  parameter VERBOSE = 1 ; //Set to 0 to only display warnings
  parameter T_HOLD = 1 ; //Delay to hold dout value after posedge. Value is arbitrary

`ifdef USE_POWER_PINS
    inout vdd;
    inout gnd;
`endif
  input  clk0; // clock
  input   csb0; // active low chip select
  input [ADDR_WIDTH-1:0]  addr0;
  input [NUM_WMASKS-1:0]   wmask0; // write mask
  input [DATA_WIDTH-1:0]  din0;
  input  clk1; // clock
  input   csb1; // active low chip select
  input [ADDR_WIDTH-1:0]  addr1;
  output [DATA_WIDTH-1:0] dout1;

  reg [DATA_WIDTH-1:0]    mem [0:RAM_DEPTH-1];

  reg  csb0_reg;
  reg [NUM_WMASKS-1:0]   wmask0_reg;
  reg [ADDR_WIDTH-1:0]  addr0_reg;
  reg [DATA_WIDTH-1:0]  din0_reg;

  // All inputs are registers
  always @(posedge clk0)
  begin
    csb0_reg = csb0;
    wmask0_reg = wmask0;
    addr0_reg = addr0;
    din0_reg = din0;
    if ( !csb0_reg && VERBOSE )
      $display($time," Writing %m addr0=%b din0=%b wmask0=%b",addr0_reg,din0_reg,wmask0_reg);
  end

  reg  csb1_reg;
  reg [ADDR_WIDTH-1:0]  addr1_reg;
  reg [DATA_WIDTH-1:0]  dout1;

  // All inputs are registers
  always @(posedge clk1)
  begin
    csb1_reg = csb1;
    addr1_reg = addr1;
    if (!csb0 && !csb1 && (addr0 == addr1))
         $display($time," WARNING: Writing and reading addr0=%b and addr1=%b simultaneously!",addr0,addr1);
    #(T_HOLD) dout1 = 512'bx;
    if ( !csb1_reg && VERBOSE ) 
      $display($time," Reading %m addr1=%b dout1=%b",addr1_reg,mem[addr1_reg]);
  end


  // Memory Write Block Port 0
  // Write Operation : When web0 = 0, csb0 = 0
  always @ (negedge clk0)
  begin : MEM_WRITE0
    if (!csb0_reg) begin
        if (wmask0_reg[0])
                mem[addr0_reg][7:0] = din0_reg[7:0];
        if (wmask0_reg[1])
                mem[addr0_reg][15:8] = din0_reg[15:8];
        if (wmask0_reg[2])
                mem[addr0_reg][23:16] = din0_reg[23:16];
        if (wmask0_reg[3])
                mem[addr0_reg][31:24] = din0_reg[31:24];
        if (wmask0_reg[4])
                mem[addr0_reg][39:32] = din0_reg[39:32];
        if (wmask0_reg[5])
                mem[addr0_reg][47:40] = din0_reg[47:40];
        if (wmask0_reg[6])
                mem[addr0_reg][55:48] = din0_reg[55:48];
        if (wmask0_reg[7])
                mem[addr0_reg][63:56] = din0_reg[63:56];
        if (wmask0_reg[8])
                mem[addr0_reg][71:64] = din0_reg[71:64];
        if (wmask0_reg[9])
                mem[addr0_reg][79:72] = din0_reg[79:72];
        if (wmask0_reg[10])
                mem[addr0_reg][87:80] = din0_reg[87:80];
        if (wmask0_reg[11])
                mem[addr0_reg][95:88] = din0_reg[95:88];
        if (wmask0_reg[12])
                mem[addr0_reg][103:96] = din0_reg[103:96];
        if (wmask0_reg[13])
                mem[addr0_reg][111:104] = din0_reg[111:104];
        if (wmask0_reg[14])
                mem[addr0_reg][119:112] = din0_reg[119:112];
        if (wmask0_reg[15])
                mem[addr0_reg][127:120] = din0_reg[127:120];
        if (wmask0_reg[16])
                mem[addr0_reg][135:128] = din0_reg[135:128];
        if (wmask0_reg[17])
                mem[addr0_reg][143:136] = din0_reg[143:136];
        if (wmask0_reg[18])
                mem[addr0_reg][151:144] = din0_reg[151:144];
        if (wmask0_reg[19])
                mem[addr0_reg][159:152] = din0_reg[159:152];
        if (wmask0_reg[20])
                mem[addr0_reg][167:160] = din0_reg[167:160];
        if (wmask0_reg[21])
                mem[addr0_reg][175:168] = din0_reg[175:168];
        if (wmask0_reg[22])
                mem[addr0_reg][183:176] = din0_reg[183:176];
        if (wmask0_reg[23])
                mem[addr0_reg][191:184] = din0_reg[191:184];
        if (wmask0_reg[24])
                mem[addr0_reg][199:192] = din0_reg[199:192];
        if (wmask0_reg[25])
                mem[addr0_reg][207:200] = din0_reg[207:200];
        if (wmask0_reg[26])
                mem[addr0_reg][215:208] = din0_reg[215:208];
        if (wmask0_reg[27])
                mem[addr0_reg][223:216] = din0_reg[223:216];
        if (wmask0_reg[28])
                mem[addr0_reg][231:224] = din0_reg[231:224];
        if (wmask0_reg[29])
                mem[addr0_reg][239:232] = din0_reg[239:232];
        if (wmask0_reg[30])
                mem[addr0_reg][247:240] = din0_reg[247:240];
        if (wmask0_reg[31])
                mem[addr0_reg][255:248] = din0_reg[255:248];
        if (wmask0_reg[32])
                mem[addr0_reg][263:256] = din0_reg[263:256];
        if (wmask0_reg[33])
                mem[addr0_reg][271:264] = din0_reg[271:264];
        if (wmask0_reg[34])
                mem[addr0_reg][279:272] = din0_reg[279:272];
        if (wmask0_reg[35])
                mem[addr0_reg][287:280] = din0_reg[287:280];
        if (wmask0_reg[36])
                mem[addr0_reg][295:288] = din0_reg[295:288];
        if (wmask0_reg[37])
                mem[addr0_reg][303:296] = din0_reg[303:296];
        if (wmask0_reg[38])
                mem[addr0_reg][311:304] = din0_reg[311:304];
        if (wmask0_reg[39])
                mem[addr0_reg][319:312] = din0_reg[319:312];
        if (wmask0_reg[40])
                mem[addr0_reg][327:320] = din0_reg[327:320];
        if (wmask0_reg[41])
                mem[addr0_reg][335:328] = din0_reg[335:328];
        if (wmask0_reg[42])
                mem[addr0_reg][343:336] = din0_reg[343:336];
        if (wmask0_reg[43])
                mem[addr0_reg][351:344] = din0_reg[351:344];
        if (wmask0_reg[44])
                mem[addr0_reg][359:352] = din0_reg[359:352];
        if (wmask0_reg[45])
                mem[addr0_reg][367:360] = din0_reg[367:360];
        if (wmask0_reg[46])
                mem[addr0_reg][375:368] = din0_reg[375:368];
        if (wmask0_reg[47])
                mem[addr0_reg][383:376] = din0_reg[383:376];
        if (wmask0_reg[48])
                mem[addr0_reg][391:384] = din0_reg[391:384];
        if (wmask0_reg[49])
                mem[addr0_reg][399:392] = din0_reg[399:392];
        if (wmask0_reg[50])
                mem[addr0_reg][407:400] = din0_reg[407:400];
        if (wmask0_reg[51])
                mem[addr0_reg][415:408] = din0_reg[415:408];
        if (wmask0_reg[52])
                mem[addr0_reg][423:416] = din0_reg[423:416];
        if (wmask0_reg[53])
                mem[addr0_reg][431:424] = din0_reg[431:424];
        if (wmask0_reg[54])
                mem[addr0_reg][439:432] = din0_reg[439:432];
        if (wmask0_reg[55])
                mem[addr0_reg][447:440] = din0_reg[447:440];
        if (wmask0_reg[56])
                mem[addr0_reg][455:448] = din0_reg[455:448];
        if (wmask0_reg[57])
                mem[addr0_reg][463:456] = din0_reg[463:456];
        if (wmask0_reg[58])
                mem[addr0_reg][471:464] = din0_reg[471:464];
        if (wmask0_reg[59])
                mem[addr0_reg][479:472] = din0_reg[479:472];
        if (wmask0_reg[60])
                mem[addr0_reg][487:480] = din0_reg[487:480];
        if (wmask0_reg[61])
                mem[addr0_reg][495:488] = din0_reg[495:488];
        if (wmask0_reg[62])
                mem[addr0_reg][503:496] = din0_reg[503:496];
        if (wmask0_reg[63])
                mem[addr0_reg][511:504] = din0_reg[511:504];
    end
  end

  // Memory Read Block Port 1
  // Read Operation : When web1 = 1, csb1 = 0
  always @ (negedge clk1)
  begin : MEM_READ1
    if (!csb1_reg)
       dout1 <= #(DELAY) mem[addr1_reg];
  end

endmodule
