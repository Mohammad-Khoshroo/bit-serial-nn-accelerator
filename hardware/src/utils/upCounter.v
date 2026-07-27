`ifndef UPCOUNTER_MODULE
`define UPCOUNTER_MODULE

        module UpCounter #(
            parameter WIDTH = 4,
            parameter INIT  = {WIDTH{1'b0}}
          )(
            input  wire clk,
            input  wire reset,
            input  wire enable,
            output wire carry_out,
            output reg  [WIDTH-1:0] count
          );

          assign carry_out = &count;

          always @(posedge clk or posedge reset)
          begin

            if (reset)
              count <= INIT;

            else if (enable)
            begin

              if (&count)
                count <= INIT;

              else
                count <= count + 1;

            end

          end

        endmodule

`endif //UPCOUNTER_MODULE
