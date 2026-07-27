`include "hw_config.vh"

module cluster_dp_sparsity #(
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
    
    input pe_start,
    output pe_done,
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

wire signed [INPUT_D_W : 0] input_signed; 
assign input_signed = $signed({1'b0, input_data}) - $signed({1'b0, input_zp});

wire [7:0] a_in = input_signed[7:0];

wire [MAX_PES-1:0] pe_ready_array;

genvar k;
generate
    for (k = 0; k < MAX_PES; k = k + 1) begin : PE_GEN
        
        wire [32:0] pe_result;
        wire [31:0] acc_out;
        
        assign acc_out = register_array[(k) * 32 +: 32];
        
        Top #(
            .W_WIDTH(WEIGHT_MEM_D_W),
            .A_WIDTH(INPUT_D_W)
        ) pe_inst (
            .clk(clk),
            .reset(~rstn),
            .start(pe_start),
            .ready(pe_ready_array[k]),
            .result(pe_result),
            .W0_in(weight_data[(k) * WEIGHT_MEM_D_W +: WEIGHT_MEM_D_W]),
            .W1_in(8'b0),
            .A0_in(a_in),
            .A1_in(8'b0),
            .initial_sum($signed(acc_out))
        );
        
        assign ra_in_acc[(k) * 32 +: 32] = pe_result[31:0];
    end
endgenerate

assign pe_done = &pe_ready_array;

endmodule