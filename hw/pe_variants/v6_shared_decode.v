// V6: V5 with shared decode. Each of a0, a1, w0, w1 is decoded ONCE and reused across the 2x2 products.
module dec_v6 (input [2:0] x, output m3, output [1:0] k, output z);
  wire [1:0] e = x[2:1];
  wire m = x[0];
  assign z  = (x == 3'd0);
  assign m3 = (e != 2'd0) & m;
  assign k  = (e == 2'd0) ? 2'd0 : (m ? (e - 2'd1) : e);
endmodule

module magprod_v6 (input m3a, input [1:0] ka, input za, input m3b, input [1:0] kb, input zb,
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

module addfold_v6 (input [12:0] c, input [7:0] mag, input s, output [12:0] d);
  wire [12:0] x = s ? ~{5'd0, mag} : {5'd0, mag};
  wire [13:0] sum = {c, 1'b1} + {x, s};
  assign d = sum[13:1];
endmodule

// bare multiplier: one decode per operand, product magnitude, sign resolved (same function as V5 mul)
module mul_v6 (input [3:0] a, input [3:0] w, output [8:0] p);
  wire m3a, m3b, za, zb;
  wire [1:0] ka, kb;
  dec_v6 da (.x(a[2:0]), .m3(m3a), .k(ka), .z(za));
  dec_v6 dw (.x(w[2:0]), .m3(m3b), .k(kb), .z(zb));
  wire [7:0] mag;
  magprod_v6 mp (.m3a(m3a), .ka(ka), .za(za), .m3b(m3b), .kb(kb), .zb(zb), .mag(mag));
  wire s = a[3] ^ w[3];
  wire [8:0] x = s ? ~{1'b0, mag} : {1'b0, mag};
  assign p = x + {8'd0, s};
endmodule

module pe_v6 (
  input  [3:0] a0, a1, w0, w1,
  input  [12:0] c00, c01, c10, c11,
  output [12:0] d00, d01, d10, d11);
  wire ma0, ma1, mw0, mw1, za0, za1, zw0, zw1;
  wire [1:0] ka0, ka1, kw0, kw1;
  dec_v6 da0 (.x(a0[2:0]), .m3(ma0), .k(ka0), .z(za0));
  dec_v6 da1 (.x(a1[2:0]), .m3(ma1), .k(ka1), .z(za1));
  dec_v6 dw0 (.x(w0[2:0]), .m3(mw0), .k(kw0), .z(zw0));
  dec_v6 dw1 (.x(w1[2:0]), .m3(mw1), .k(kw1), .z(zw1));
  wire [7:0] m00, m01, m10, m11;
  magprod_v6 p00 (.m3a(ma0), .ka(ka0), .za(za0), .m3b(mw0), .kb(kw0), .zb(zw0), .mag(m00));
  magprod_v6 p01 (.m3a(ma0), .ka(ka0), .za(za0), .m3b(mw1), .kb(kw1), .zb(zw1), .mag(m01));
  magprod_v6 p10 (.m3a(ma1), .ka(ka1), .za(za1), .m3b(mw0), .kb(kw0), .zb(zw0), .mag(m10));
  magprod_v6 p11 (.m3a(ma1), .ka(ka1), .za(za1), .m3b(mw1), .kb(kw1), .zb(zw1), .mag(m11));
  addfold_v6 f00 (.c(c00), .mag(m00), .s(a0[3] ^ w0[3]), .d(d00));
  addfold_v6 f01 (.c(c01), .mag(m01), .s(a0[3] ^ w1[3]), .d(d01));
  addfold_v6 f10 (.c(c10), .mag(m10), .s(a1[3] ^ w0[3]), .d(d10));
  addfold_v6 f11 (.c(c11), .mag(m11), .s(a1[3] ^ w1[3]), .d(d11));
endmodule
