`ifndef ONE_HOT_DECODER_ACTIVE_LOW_MODULE
`define ONE_HOT_DECODER_ACTIVE_LOW_MODULE

        module Decoder_low #(
            parameter ADDR_WIDTH = 3
          ) (
            input  wire [ADDR_WIDTH-1:0] addr,
            input  wire                  en,
            output reg  [(1<<ADDR_WIDTH)-1:0] out
          );

          always @(*)
          begin
            if (en)
            begin
              out = {(1<<ADDR_WIDTH){1'b1}};
              out[addr] = 1'b0;
            end
            else
              out = {(1<<ADDR_WIDTH){1'b1}};
            
          end

        endmodule

`endif //ONE_HOT_DECODER_ACTIVE_LOW_MODULE
