// V3: decode each operand to a signed integer (doubled value), generic signed `*`, then add.
module dec_v3 (input [3:0] x, output reg signed [4:0] v);
  reg [3:0] m;
  always @* begin
    case (x[2:0])
      3'd0: m = 4'd0;  3'd1: m = 4'd1;  3'd2: m = 4'd2;  3'd3: m = 4'd3;
      3'd4: m = 4'd4;  3'd5: m = 4'd6;  3'd6: m = 4'd8;  default: m = 4'd12;
    endcase
    v = x[3] ? -$signed({1'b0, m}) : $signed({1'b0, m});
  end
endmodule

module mul_v3 (input [3:0] a, input [3:0] w, output [8:0] p);
  wire signed [4:0] va, vw;
  dec_v3 da (.x(a), .v(va));
  dec_v3 dw (.x(w), .v(vw));
  wire signed [9:0] full = va * vw;
  assign p = full[8:0];
endmodule

module pe_v3 (
  input  [3:0] a0, a1, w0, w1,
  input  [12:0] c00, c01, c10, c11,
  output [12:0] d00, d01, d10, d11);
  wire [8:0] p00, p01, p10, p11;
  mul_v3 u00 (.a(a0), .w(w0), .p(p00));
  mul_v3 u01 (.a(a0), .w(w1), .p(p01));
  mul_v3 u10 (.a(a1), .w(w0), .p(p10));
  mul_v3 u11 (.a(a1), .w(w1), .p(p11));
  assign d00 = c00 + {{4{p00[8]}}, p00};
  assign d01 = c01 + {{4{p01[8]}}, p01};
  assign d10 = c10 + {{4{p10[8]}}, p10};
  assign d11 = c11 + {{4{p11[8]}}, p11};
endmodule
