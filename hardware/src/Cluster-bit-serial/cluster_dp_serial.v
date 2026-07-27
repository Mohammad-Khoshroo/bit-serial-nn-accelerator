`include "hw_config.vh"

module cluster_dp_serial #(
    parameter integer PE_D_W = `PE_D_W,
    parameter integer PE_A_W = `PE_A_W,
    parameter integer MAX_INPUT_SIZE = `MAX_INPUT_SIZE,
    parameter integer INPUT_WEIGHT_ADDR_WIDTH = $clog2(MAX_INPUT_SIZE),
    parameter integer MAX_PES = `MAX_PES,
    parameter integer INPUT_D_W = `INPUT_D_W,
    parameter integer WEIGHT_MEM_D_W = `WEIGHT_MEM_D_W,
    parameter integer BYTE_REG_NUM = 128
) (
    input clk, rstn,
    input [$clog2(MAX_INPUT_SIZE) - 1 : 0] input_size,
    input [$clog2(MAX_PES) - 1 : 0] output_size,
    input [INPUT_D_W - 1 : 0] input_data,
    input signed [WEIGHT_MEM_D_W * MAX_PES - 1 : 0] weight_data,
    output [ INPUT_WEIGHT_ADDR_WIDTH - 1 : 0 ] input_weight_address,
    input input_counter_clr,
    input input_counter_ld,
    output input_counter_co,
    input [`INPUT_ZP_WIDTH-1:0] input_zp,
    input is_msb,
    input is_lsb,
    input is_valid,
    output [3:0] bit_index,
    output bit_co,
    output reg [BYTE_REG_NUM * 8-1:0] ra_in_acc,
    input [BYTE_REG_NUM * 8-1:0] register_array
);

reg [INPUT_WEIGHT_ADDR_WIDTH-1 : 0] input_counter_r;
always @(posedge clk) begin
    if(input_counter_ld)
        input_counter_r <= input_counter_r + 1;
    if (input_counter_clr | !rstn)
        input_counter_r <= 0; 
end
assign input_counter_co = input_counter_r >= input_size;
assign input_weight_address = input_counter_r;

// Bit Counter
reg [3:0] bit_counter;
always @(posedge clk) begin
    if (!rstn) begin
        bit_counter <= 4'd8;
    end else begin
        if (is_lsb) begin
            bit_counter <= 4'd8;
        end else if (is_msb) begin
            bit_counter <= 4'd7;
        end else if (is_valid) begin
            if (bit_counter == 4'd0)
                bit_counter <= 4'd8;
            else
                bit_counter <= bit_counter - 1;
        end
    end
end
assign bit_index = bit_counter;
assign bit_co = (bit_counter == 4'd0) && is_valid;

wire signed [INPUT_D_W : 0] input_signed; 
assign input_signed = $signed({1'b0, input_data}) - $signed({1'b0, input_zp});

genvar k;
generate
    for (k = 0; k < MAX_PES; k = k + 1) begin : PE_GEN
        wire [31:0] acc_out;
        wire [31:0] pe_out;
        
        assign acc_out = register_array[(k) * 32 +: 32];
        
        wire a_bit = input_signed[bit_index]; 

        wire signed [WEIGHT_MEM_D_W-1:0] weight = weight_data[(k) * WEIGHT_MEM_D_W +: WEIGHT_MEM_D_W];
        wire [WEIGHT_MEM_D_W:0] weight_s;
        assign weight_s = {weight[WEIGHT_MEM_D_W-1], weight};

        Stripes pe_inst (
            .clk(clk),
            .reset(~rstn),
            .i_is_msb(is_msb),
            .i_is_lsb(is_lsb),
            .i_is_valid(is_valid),
            .a_bits(a_bit),
            .b_vec(weight_s),
            .initial_sum(acc_out),
            .o_dot_product(pe_out)
        );
        
        assign ra_in_acc[(k) * 32 +: 32] = pe_out;
    end
endgenerate

endmodule