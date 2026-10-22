  // ---- M7.P0 additions (inserted by patch_testdriver.py; the rest of this file is the unmodified Chipyard TestDriver.v) ----
  // Note: $dumpon/$dumpoff are ignored by the simulator here (tested with v5.022), so the dump window is: $dumpvars at cycle N, $finish at M+1 (the VCD closes at $finish).
  // Cycle counter (in GEMMINI clock cycles: the tile/Gemmini clock is half the TestDriver clock) + window control: +m7p-start=N +m7p-end=M dumps the waveform only for cycles N..M (inclusive).
  // Monitor: prints the Gemmini RoCC command fires (when funct changes) and io_busy edges, with the cycle number.
  reg [63:0] m7p_cyc = 0;
  reg [63:0] m7p_start = 0;
  reg [63:0] m7p_end = 0;
  reg [63:0] m7p_nfire = 0;
  reg [63:0] m7p_nprint = 0;
  reg [6:0]  m7p_pfunct = 7'h7f;
  reg        m7p_pbusy = 1'b0;
  reg        m7p_dumping = 1'b0;
  wire m7p_fire = `M7P_GEM.io_cmd_valid & `M7P_GEM.io_cmd_ready;
  initial begin
    void'($value$plusargs("m7p-start=%d", m7p_start));
    void'($value$plusargs("m7p-end=%d", m7p_end));
  end
  always @(posedge `M7P_GEM.clock) begin
    m7p_cyc = m7p_cyc + 1;
    if (m7p_has_win) begin
      if (m7p_cyc == m7p_start) begin $dumpvars(0, testHarness); m7p_dumping = 1'b1; $display("M7P DUMPON cycle=%0d t_ns=%0.3f", m7p_cyc, $realtime); end
      if (m7p_cyc == m7p_end + 1) begin m7p_dumping = 1'b0; $display("M7P DUMPOFF cycle=%0d t_ns=%0.3f", m7p_cyc, $realtime); $finish; end
    end
    if (!`M7P_GEM.reset) begin
      if (m7p_fire) begin
        m7p_nfire = m7p_nfire + 1;
        if (m7p_nfire == 1 || `M7P_GEM.io_cmd_bits_inst_funct != m7p_pfunct) begin
          if (m7p_nprint < 4000) $display("M7P FIRE cycle=%0d t_ns=%0.3f n=%0d funct=%0d", m7p_cyc, $realtime, m7p_nfire, `M7P_GEM.io_cmd_bits_inst_funct);
          m7p_nprint = m7p_nprint + 1;
        end
        m7p_pfunct = `M7P_GEM.io_cmd_bits_inst_funct;
      end
      if (`M7P_GEM.io_busy != m7p_pbusy) $display("M7P BUSY%0d cycle=%0d t_ns=%0.3f nfire=%0d", `M7P_GEM.io_busy, m7p_cyc, $realtime, m7p_nfire);
      m7p_pbusy = `M7P_GEM.io_busy;
    end
  end
  final $display("M7P END cycle=%0d nfire=%0d", m7p_cyc, m7p_nfire);
