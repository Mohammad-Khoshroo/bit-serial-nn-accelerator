`include "hw_config.vh"

module cluster_ctrl_serial(
    input clk,
    input rstn,
    input start,
    output reg logic_wen,
    output reg done,
    output reg ra_ld_axi,
    output reg ra_ld_acc,
    output reg axi_ram_ld,
    output reg input_weight_ren,
    output reg input_counter_clr,
    output reg input_counter_ld,
    input input_counter_co,
    input bit_co,
    output reg is_msb,
    output reg is_lsb,
    output reg is_valid
);

localparam [2:0] 
    S_IDLE         = 0, 
    S_LD_BETA      = 1, 
    S_CALCULATE    = 2, 
    S_MSB          = 3, 
    S_MULTIPLY     = 4, 
    S_LSB          = 5, 
    S_WRITE_TO_MEM = 6, 
    S_WAIT_ACK     = 7;

reg [2:0] ps, ns;

always @(posedge clk) begin
    if (!rstn) ps <= S_IDLE;
    else       ps <= ns;
end

always @(*) begin
    ns = S_IDLE;
    case(ps)
    S_IDLE:         ns = start ? S_LD_BETA : S_IDLE;
    S_LD_BETA:      ns = S_CALCULATE;
    S_CALCULATE:    ns = S_MSB;
    S_MSB:          ns = S_MULTIPLY;
    S_MULTIPLY:     ns = bit_co ? S_LSB : S_MULTIPLY;
    S_LSB:          ns = input_counter_co ? S_WRITE_TO_MEM : S_CALCULATE;
    S_WRITE_TO_MEM: ns = S_WAIT_ACK;
    S_WAIT_ACK:     ns = ~start ? S_IDLE : S_WAIT_ACK;
    endcase
end

always @(*) begin
    {done, ra_ld_acc, input_weight_ren, ra_ld_axi, input_counter_clr, input_counter_ld, axi_ram_ld, logic_wen} = 0;
    {is_msb, is_lsb, is_valid} = 0;
    
    case(ps)
    S_IDLE: input_counter_clr = 1'b1;
    S_LD_BETA: ra_ld_axi = 1'b1;
    
    S_CALCULATE: begin
        input_weight_ren = 1'b1; 
    end
    
    S_MSB: begin
        is_valid = 1'b1;
        is_msb = 1'b1;
        input_weight_ren = 1'b1;
    end
    
    S_MULTIPLY: begin
        is_valid = 1'b1;
        input_weight_ren = 1'b1;
    end
    
    S_LSB: begin
        is_valid = 1'b0;
        ra_ld_acc = 1'b1;
        is_lsb = 1'b1;      
        input_counter_ld = 1'b1;
        input_weight_ren = 1'b1;
    end
    
    S_WRITE_TO_MEM: {axi_ram_ld, logic_wen, done} = 3'b111;
    S_WAIT_ACK:     {logic_wen, done} = {~start, start};
    endcase
end

endmodule