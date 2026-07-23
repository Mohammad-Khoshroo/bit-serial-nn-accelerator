`include "hw_config.vh"

module cluster_top #(
    parameter integer MAX_INPUT_SIZE = `MAX_INPUT_SIZE,
    parameter integer INPUT_D_W = `INPUT_D_W,
    parameter integer MAX_PES = `MAX_PES,
    parameter integer PE_D_W = `PE_D_W,

    parameter integer CONFIG_SIZE = 8,
    parameter integer BLOCK_NUM = `MAX_PES + 1,
    parameter integer BLOCK_SIZE = `MAX_INPUT_SIZE,
    parameter integer DATA_WIDTH = `WEIGHT_MEM_D_W,
    parameter integer INPUT_WEIGHT_ADDR_WIDTH = $clog2(MAX_INPUT_SIZE),
    parameter integer WEIGHT_DATA_WIDTH = `WEIGHT_MEM_D_W,
    parameter integer INPUT_DATA_WIDTH = `INPUT_D_W,

    parameter integer BYTE_REG_NUM = 128

    
) (
    input clk, rstn,
    // configs
    input [$clog2(MAX_INPUT_SIZE) - 1 : 0] input_num,
    input [$clog2(MAX_PES) - 1 : 0] output_num,
    input relu,

    input [`INPUT_ZP_WIDTH-1:0] input_zp,
    input start,
    output done,
    output logic_wen,
/////////////////////////////////
    output input_weight_ren,
    output [ INPUT_WEIGHT_ADDR_WIDTH - 1 : 0 ] input_weight_address,
    input [ MAX_PES * WEIGHT_DATA_WIDTH - 1 : 0] weight_data,
    input [INPUT_DATA_WIDTH - 1 : 0] input_data,
/////////////////////////////////////
    output ra_ld_axi,
    output ra_ld_acc,
    output axi_ram_ld,
    output [BYTE_REG_NUM * 8-1:0] ra_in_acc,
    input [BYTE_REG_NUM * 8-1:0] register_array

);

wire input_counter_clr;
wire input_counter_ld;
wire input_counter_co;




cluster_dp MDP(
    .clk(clk),
    .rstn(rstn),
    .input_size(input_num),
    .output_size(output_num),

    .input_data(input_data),
    .weight_data(weight_data),

    .input_weight_address(input_weight_address),
    .input_zp(input_zp),

    .input_counter_clr(input_counter_clr),
    .input_counter_ld(input_counter_ld),
    .input_counter_co(input_counter_co),

    .register_array(register_array),
    .ra_in_acc(ra_in_acc)


    
);


cluster_ctrl MCTRL(
    .clk(clk),
    .rstn(rstn),
    .start(start),
    .done(done),
    .logic_wen(logic_wen),
    .ra_ld_axi(ra_ld_axi),
    .ra_ld_acc(ra_ld_acc),
    .axi_ram_ld(axi_ram_ld),
    .input_weight_ren(input_weight_ren),
    .input_counter_clr(input_counter_clr),
    .input_counter_ld(input_counter_ld),
    .input_counter_co(input_counter_co)
     );

endmodule