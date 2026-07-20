`include "hw_config.vh"

module cluster_dp #(
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

    
    output reg [BYTE_REG_NUM * 8-1:0] ra_in_acc,
    input [BYTE_REG_NUM * 8-1:0] register_array
    
    );

    
    wire signed [PE_D_W - 1 : 0] ra_in [`MAX_PES - 1:0];
    wire signed [PE_D_W - 1 : 0] ra_mat_temp [`MAX_PES - 1:0];
    reg [PE_D_W - 1 : 0] ra_out [`MAX_PES - 1:0];
    reg signed [WEIGHT_MEM_D_W - 1 : 0] weight_data_i[`MAX_PES - 1 : 0];

    
    reg [PE_A_W : 0] n_i;
    
    wire [PE_D_W * MAX_PES - 1 : 0] rf_in;
    
always @(*) begin

    for (n_i = 0; n_i < MAX_PES; n_i = n_i +1) begin
        ra_out[n_i] = register_array[(n_i) * PE_D_W +: PE_D_W];
        ra_in_acc[(n_i) * PE_D_W +: PE_D_W] = ra_in[n_i];
        weight_data_i[n_i] = weight_data[(n_i) * WEIGHT_MEM_D_W +: WEIGHT_MEM_D_W];
    end
end


reg [INPUT_WEIGHT_ADDR_WIDTH-1 : 0] input_counter_r;


always @(posedge clk) begin
    if(input_counter_ld)
        input_counter_r <= input_counter_r + 1;

    if (input_counter_clr | !rstn)
        input_counter_r <= 0; 

end

assign input_counter_co = input_counter_r >= input_size;

assign input_weight_address = input_counter_r;


wire signed [ 8 : 0] input_signed; 
assign input_signed = input_data - input_zp;

genvar k;
generate
    for (k = 0; k < MAX_PES; k = k + 1) begin

        assign ra_mat_temp[k] = input_signed * weight_data_i[k];
        assign ra_in[k] = ra_out[k] + ra_mat_temp[k]; 
        
    end
endgenerate

endmodule