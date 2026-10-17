// V5: V4 magnitude path, sign folded into the column adder (no separate negate):
//   d = c + (s ? ~mag : mag) + s   with s as the adder carry-in, realised as one adder on {c,1}+{x,s}.
// -0 case: mag=0 and s=1 gives c + (-1) + 1 = c, so no zero special-casing is needed.
module dec_v5 (input [2:0] x, output m3, output [1:0] k, output z);
  wire [1:0] e = x[2:1];
  wire m = x[0];
  assign z  = (x == 3'd0);
  assign m3 = (e != 2'd0) & m;
  assign k  = (e == 2'd0) ? 2'd0 : (m ? (e - 2'd1) : e);
endmodule

module magprod_v5 (input m3a, input [1:0] ka, input za, input m3b, input [1:0] kb, input zb,
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

// per-product magnitude + sign (decode per product, as in V1-V4)
module magsign_v5 (input [3:0] a, input [3:0] w, output [7:0] mag, output s);
  wire m3a, m3b, za, zb;
  wire [1:0] ka, kb;
  dec_v5 da (.x(a[2:0]), .m3(m3a), .k(ka), .z(za));
  dec_v5 dw (.x(w[2:0]), .m3(m3b), .k(kb), .z(zb));
  magprod_v5 mp (.m3a(m3a), .ka(ka), .za(za), .m3b(m3b), .kb(kb), .zb(zb), .mag(mag));
  assign s = a[3] ^ w[3];
endmodule

// c + (s ? ~mag : mag) + s  -- one adder, carry-in = s
module addfold_v5 (input [12:0] c, input [7:0] mag, input s, output [12:0] d);
  wire [12:0] x = s ? ~{5'd0, mag} : {5'd0, mag};
  wire [13:0] sum = {c, 1'b1} + {x, s};
  assign d = sum[13:1];
endmodule

// bare multiplier view: nothing to fold into, so resolve the sign to a 9-bit signed value (~mag + s)
module mul_v5 (input [3:0] a, input [3:0] w, output [8:0] p);
  wire [7:0] mag;
  wire s;
  magsign_v5 ms (.a(a), .w(w), .mag(mag), .s(s));
  wire [8:0] x = s ? ~{1'b0, mag} : {1'b0, mag};
  assign p = x + {8'd0, s};
endmodule

module pe_v5 (
  input  [3:0] a0, a1, w0, w1,
  input  [12:0] c00, c01, c10, c11,
  output [12:0] d00, d01, d10, d11);
  wire [7:0] m00, m01, m10, m11;
  wire s00, s01, s10, s11;
  magsign_v5 u00 (.a(a0), .w(w0), .mag(m00), .s(s00));
  magsign_v5 u01 (.a(a0), .w(w1), .mag(m01), .s(s01));
  magsign_v5 u10 (.a(a1), .w(w0), .mag(m10), .s(s10));
  magsign_v5 u11 (.a(a1), .w(w1), .mag(m11), .s(s11));
  addfold_v5 f00 (.c(c00), .mag(m00), .s(s00), .d(d00));
  addfold_v5 f01 (.c(c01), .mag(m01), .s(s01), .d(d01));
  addfold_v5 f10 (.c(c10), .mag(m10), .s(s10), .d(d10));
  addfold_v5 f11 (.c(c11), .mag(m11), .s(s11), .d(d11));
endmodule
