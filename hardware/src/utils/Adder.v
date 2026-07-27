`ifndef ADDER_MODULE
`define ADDER_MODULE

        module Adder (
            input  [47:0] in,
            input  carry_in,
            output [15:0] sum,
            output        carry
          );

          wire [16:0] s0, s1, s2;

          assign s0 = {1'b0, in[15:0]}   + carry_in;
          assign s1 = {1'b0, in[31:16]}  + s0[15:0];
          assign s2 = {1'b0, in[47:32]}  + s1[15:0];

          assign sum   = s2[15:0];
          assign carry = s2[16];

        endmodule

`endif
