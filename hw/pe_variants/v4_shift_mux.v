// V4: structured shift-mux. Per-operand decode to (m3, k, zero); magnitude = {1,3,9} << (ka+kb); negate; add.
// Decode (D1 table): e=0 -> value m (m'=1,k=0; zero if m=0); e>=1,m=0 -> m'=1,k=e; e>=1,m=1 -> m'=3,k=e-1.
module dec_v4 (input [2:0] x, output m3, output [1:0] k, output z);
  wire [1:0] e = x[2:1];
  wire m = x[0];
  assign z  = (x == 3'd0);
  assign m3 = (e != 2'd0) & m;
  assign k  = (e == 2'd0) ? 2'd0 : (m ? (e - 2'd1) : e);
endmodule

// magnitude (8-bit) from two decoded operands: mux{1,3,9} << (ka+kb); max 9<<4 = 144 so 8 bits suffice
module magprod_v4 (input m3a, input [1:0] ka, input za, input m3b, input [1:0] kb, input zb,
                   output [7:0] mag);
  reg [3:0] base;
  always @* begin
    case ({m3a, m3b})
      2'b00: base = 4'd1;
      2'b01: base = 4'd3;
      2'b10: base = 4'd3;
      default: base = 4'd9;
    endcase
  end
  wire [2:0] ks = {1'b0, ka} + {1'b0, kb};
  wire [7:0] sh = {4'd0, base} << ks;
  assign mag = (za | zb) ? 8'd0 : sh;
endmodule

module mul_v4 (input [3:0] a, input [3:0] w, output [8:0] p);
  wire m3a, m3b, za, zb;
  wire [1:0] ka, kb;
  dec_v4 da (.x(a[2:0]), .m3(m3a), .k(ka), .z(za));
  dec_v4 dw (.x(w[2:0]), .m3(m3b), .k(kb), .z(zb));
  wire [7:0] mag;
  magprod_v4 mp (.m3a(m3a), .ka(ka), .za(za), .m3b(m3b), .kb(kb), .zb(zb), .mag(mag));
  wire s = a[3] ^ w[3];
  assign p = s ? (9'd0 - {1'b0, mag}) : {1'b0, mag};
endmodule

module pe_v4 (
  input  [3:0] a0, a1, w0, w1,
  input  [12:0] c00, c01, c10, c11,
  output [12:0] d00, d01, d10, d11);
  wire [8:0] p00, p01, p10, p11;
  mul_v4 u00 (.a(a0), .w(w0), .p(p00));
  mul_v4 u01 (.a(a0), .w(w1), .p(p01));
  mul_v4 u10 (.a(a1), .w(w0), .p(p10));
  mul_v4 u11 (.a(a1), .w(w1), .p(p11));
  assign d00 = c00 + {{4{p00[8]}}, p00};
  assign d01 = c01 + {{4{p01[8]}}, p01};
  assign d10 = c10 + {{4{p10[8]}}, p10};
  assign d11 = c11 + {{4{p11[8]}}, p11};
endmodule
