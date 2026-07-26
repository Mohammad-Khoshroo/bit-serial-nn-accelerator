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

        module Stripes#(
            parameter  N = 4,
            parameter  W_WIDTH = 16,
            parameter  MP = 16,
            parameter ACC_WIDTH  = W_WIDTH + $clog2(N) + MP
          ) (
            input   clk,
            input   reset,
            input   i_is_msb,
            input   i_is_lsb,
            input   i_is_valid,
            input   [N-1:0] a_bits,
            input   [W_WIDTH*N-1:0] b_vec,
            input   [ACC_WIDTH-1:0] initial_sum,
            output  [ACC_WIDTH-1:0] o_dot_product
          );



          // Multiply Part

          wire [W_WIDTH-1:0] weights        [0:N-1];
          wire [W_WIDTH-1:0] weights_2comp  [0:N-1];
          wire [W_WIDTH-1:0] bit_product    [0:N-1];
          wire [W_WIDTH-1:0] multiply_in    [0:N-1];

          genvar i;
          generate
            for (i = 0; i < N; i = i + 1)
            begin
              assign weights[i]       = b_vec[i*W_WIDTH +: W_WIDTH];
              assign weights_2comp[i] = ~b_vec[i*W_WIDTH +: W_WIDTH] + 1;
              assign multiply_in[i]   = i_is_msb ? weights_2comp[i] : weights[i];
              assign bit_product[i]  = a_bits[i] ? multiply_in[i] : {W_WIDTH{1'b0}};

              wire [W_WIDTH-1:0] wave_weights       = weights[i];
              wire [W_WIDTH-1:0] wave_weights_2comp = weights_2comp[i];
              wire [W_WIDTH-1:0] wave_mult_in       = multiply_in[i];
              wire [W_WIDTH-1:0] wave_mult_out      = bit_product[i];

            end
          endgenerate

          // Sum of one-bit Multiply part
          integer j;

          reg signed  [ACC_WIDTH-1:0] product_sum;

          always @(*)
          begin
            product_sum = {ACC_WIDTH{1'b0}};
            for (j = 0; j < N; j = j + 1)
              product_sum = product_sum + $signed(bit_product[j]);
          end

          // Accumolation
          wire [ACC_WIDTH-1:0] acc_sum;
          wire [ACC_WIDTH-1:0] shifted_acc_sum;
          wire [ACC_WIDTH-1:0] new_acc_sum;

          assign shifted_acc_sum = {acc_sum[ACC_WIDTH-2:0],1'b0};
          assign new_acc_sum = shifted_acc_sum + product_sum;

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
