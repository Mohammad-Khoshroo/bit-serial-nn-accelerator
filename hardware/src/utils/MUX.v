`ifndef MUX_MODULE
`define MUX_MODULE

        module MUX #(
            parameter WIDTH = 8,
            parameter N_INPUTS = 4
          )(
            input [WIDTH*N_INPUTS-1:0] inputs,
            input [$clog2(N_INPUTS)-1:0] select,
            output[WIDTH-1:0] out
          );

          assign out = inputs[select * WIDTH +: WIDTH];

        endmodule

`endif //MUX_MODULE
