`ifndef TOP_MODULE
`define TOP_MODULE

        module Top #(
            parameter W_WIDTH = 8 ,
            parameter A_WIDTH = 8
          )(
            input clk,
            input reset,
            input start,
            output ready,
            output [ACC_WIDTH:0] result,
            input  [W_WIDTH-1:0] W0_in,
            input  [W_WIDTH-1:0] W1_in,
            input  [A_WIDTH-1:0] A0_in,
            input  [A_WIDTH-1:0] A1_in,
            input [ACC_WIDTH:0] initial_sum 
          );

          parameter ACC_WIDTH = 32;

          wire done;
          assign done = lsb0 & lsb1;

          FSM controller(
                .clk(clk),
                .reset(reset),
                .start(start),
                .done(done),
                .Areg_en(Areg_en),
                .Areg_pl(Areg_pl),
                .Wreg_en(Wreg_en),
                .acc_en(acc_en),
                .acc_pl(acc_pl),
                .ready(ready)
              );

          wire Areg_en,Areg_pl;
          wire  [A_WIDTH-1:0] A0,A1;
          wire  [A_WIDTH-1:0] A0_new,A1_new;
          Register #(
                     .WIDTH(A_WIDTH)
                   )
                   A0reg(
                     .clk(clk),
                     .reset(reset),
                     .enable(Areg_en),
                     .pl_enable(Areg_pl),
                     .pl(A0_new),
                     .d(A0_in),
                     .q(A0)
                   );

          wire [$clog2(A_WIDTH)-1:0] shift_count0;
          wire lsb0;
          assign lsb0 = ~|A0;
          PriorityEncoder #(
                            .WIDTH(A_WIDTH)
                          )
                          lod0(
                            .in(A0),
                            .index(shift_count0)
                          );

          wire [A_WIDTH-1:0] oneHot_decode0;
          assign A0_new = oneHot_decode0 & A0;
          Decoder_low #(
                        .ADDR_WIDTH($clog2(A_WIDTH))
                      )
                      decode0(
                        .addr(shift_count0),
                        .en(1'b1),
                        .out(oneHot_decode0)
                      );
                        
          Register #(
                     .WIDTH(A_WIDTH)
                   )
                   A1reg(
                     .clk(clk),
                     .reset(reset),
                     .enable(Areg_en),
                     .pl_enable(Areg_pl),
                     .pl(A1_new),
                     .d(A1_in),
                     .q(A1)
                   );

          wire [$clog2(A_WIDTH)-1:0] shift_count1;
          wire lsb1;
          assign lsb1 = ~|A1;
          PriorityEncoder #(
                            .WIDTH(A_WIDTH)
                          )
                          lod1(
                            .in(A1),
                            .index(shift_count1)
                          );

          wire [A_WIDTH-1:0] oneHot_decode1;
          assign A1_new = oneHot_decode1 & A1;
          Decoder_low #(
                        .ADDR_WIDTH($clog2(A_WIDTH))
                      )
                      decode1(
                        .addr(shift_count1),
                        .en(1'b1),
                        .out(oneHot_decode1)
                      );

          wire Wreg_en;
          wire  [W_WIDTH-1:0] W0,W1;
          wire  [ACC_WIDTH-1:0] W0_extend,W1_extend;

          wire signed [W_WIDTH-1:0] W0_s = W0;
          wire signed [W_WIDTH-1:0] W1_s = W1;
          assign  W0_extend = {{(ACC_WIDTH-W_WIDTH){W0_s[W_WIDTH-1]}}, W0_s};
          assign  W1_extend = {{(ACC_WIDTH-W_WIDTH){W1_s[W_WIDTH-1]}}, W1_s};

          Register #(
                     .WIDTH(W_WIDTH)
                   )
                   W0reg(
                     .clk(clk),
                     .reset(reset),
                     .enable(Wreg_en),
                     .pl_enable(1'b0),
                     .pl({W_WIDTH{1'b0}}),
                     .d(W0_in),
                     .q(W0)
                   );

          Register #(
                     .WIDTH(W_WIDTH)
                   )
                   W1reg(
                     .clk(clk),
                     .reset(reset),
                     .enable(Wreg_en),
                     .pl_enable(1'b0),
                     .pl({W_WIDTH{1'b0}}),
                     .d(W1_in),
                     .q(W1)
                   );

          wire  [ACC_WIDTH-1:0] W0_shifted,W1_shifted;
          BarrelShifter #(
                          .WIDTH(ACC_WIDTH)
                        )
                        W0_shift(
                          .data_in(W0_extend),
                          .shift_amount(shift_count0),
                          .direction(1'b0),
                          .data_out(W0_shifted)
                        );

          BarrelShifter #(
                          .WIDTH(ACC_WIDTH)
                        )
                        W1_shift(
                          .data_in(W1_extend),
                          .shift_amount(shift_count1),
                          .direction(1'b0),
                          .data_out(W1_shifted)
                        );

          wire is_msb0 = (shift_count0 == A_WIDTH-1);
          wire is_msb1 = (shift_count1 == A_WIDTH-1);
          
          wire signed [ACC_WIDTH-1:0] p0 = is_msb0 ? -$signed(W0_shifted) : $signed(W0_shifted);
          wire signed [ACC_WIDTH-1:0] p1 = is_msb1 ? -$signed(W1_shifted) : $signed(W1_shifted);

          wire signed [ACC_WIDTH:0] prod0_ext = $signed(p0);
          wire signed [ACC_WIDTH:0] prod1_ext = $signed(p1);
          
          wire signed [ACC_WIDTH:0] product0 = lsb0 ? 33'sd0 : prod0_ext;
          wire signed [ACC_WIDTH:0] product1 = lsb1 ? 33'sd0 : prod1_ext;
          
          wire signed [ACC_WIDTH:0] result_s = $signed(result);
          wire signed [ACC_WIDTH:0] product_sum = result_s + product0 + product1;

          wire acc_en,acc_pl;
          Register #(
                     .WIDTH(ACC_WIDTH + 1)
                   )
                   ACCreg(
                     .clk(clk),
                     .reset(reset),
                     .enable(acc_en),
                     .pl_enable(acc_pl),
                     .pl(initial_sum),
                     .d(product_sum),
                     .q(result)
                   );

        endmodule

`endif //TOP_MODULE