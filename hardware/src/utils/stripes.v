`ifndef REGISTER_CLEAR_MODULE
`define REGISTER_CLEAR_MODULE

        module RegisterC #(
            parameter WIDTH = 32,
            parameter INIT = {WIDTH{1'b0}}
          )(
            input wire clk,
            input wire reset,
            input wire enable,
            input wire clear,
            input wire [WIDTH-1:0] d,
            output reg [WIDTH-1:0] q
          );

          always @(posedge clk or posedge reset)
          begin
            if (reset | clear)
              q <= INIT;
            else if (enable)
              q <= d;
          end

        endmodule

`endif // REGISTER_CLEAR_MODULE

`ifndef STRIPES_MODULE
`define STRIPES_MODULE

        module Stripes #(
            parameter  W_WIDTH = 8,
            parameter  MP = 9,
            parameter  ACC_WIDTH = 33
          ) (
            input   clk,
            input   reset,
            input   i_is_msb,
            input   i_is_lsb,
            input   i_is_valid,
            input   a_bits,             
            input   [W_WIDTH-1:0] b_vec, 
            input   [ACC_WIDTH-1:0] initial_sum,
            output  [ACC_WIDTH-1:0] o_dot_product
          );

          // Multiply Part
          wire [W_WIDTH-1:0] weight       = b_vec;
          wire [W_WIDTH-1:0] weight_2comp = ~b_vec + 1;
          wire [W_WIDTH-1:0] multiply_in  = i_is_msb ? weight_2comp : weight;
          wire [W_WIDTH-1:0] bit_product  = a_bits ? multiply_in : {W_WIDTH{1'b0}};

          // Sum of one-bit Multiply part
          wire signed [ACC_WIDTH-1:0] product_sum = $signed(bit_product);

          // Accumulation
          wire [ACC_WIDTH-1:0] acc_sum;
          wire [ACC_WIDTH-1:0] shifted_acc_sum;
          wire [ACC_WIDTH-1:0] new_acc_sum;

          assign shifted_acc_sum = {acc_sum[ACC_WIDTH-2:0], 1'b0};
          assign new_acc_sum     = shifted_acc_sum + product_sum;

          RegisterC #(
                      .WIDTH(ACC_WIDTH)
                    )
                    acc_register(
                      .clk(clk),
                      .reset(reset),
                      .enable(i_is_valid),
                      .clear(i_is_lsb),
                      .d(new_acc_sum),
                      .q(acc_sum)
                    );

          assign  o_dot_product = initial_sum + acc_sum;

        endmodule

`endif //STRIPES_MODULE