`include "hw_config.vh"

module cluster_ctrl_sparsity(
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
    input pe_done,          
    output reg pe_start     
);

localparam [2:0] 
    S_IDLE         = 0, 
    S_LD_BETA      = 1, 
    S_CALC_START   = 2, 
    S_WAIT_READY   = 3, 
    S_WRITE_TO_MEM = 4, 
    S_WAIT_ACK     = 5;

reg [2:0] ps, ns;

always @(posedge clk) begin
    if (!rstn) ps <= S_IDLE;
    else       ps <= ns;
end

always @(*) begin
    ns = S_IDLE;
    case(ps)
    S_IDLE:         ns = start ? S_LD_BETA : S_IDLE;
    S_LD_BETA:      ns = S_CALC_START;
    S_CALC_START:   ns = S_WAIT_READY;
    S_WAIT_READY:   ns = pe_done ? (input_counter_co ? S_WRITE_TO_MEM : S_CALC_START) : S_WAIT_READY;
    S_WRITE_TO_MEM: ns = S_WAIT_ACK;
    S_WAIT_ACK:     ns = ~start ? S_IDLE : S_WAIT_ACK;
    endcase
end

always @(*) begin
    {done, ra_ld_acc, input_weight_ren, ra_ld_axi, input_counter_clr, input_counter_ld, axi_ram_ld, logic_wen, pe_start} = 0;
    
    case(ps)
    S_IDLE: input_counter_clr = 1'b1;
    
    S_LD_BETA: ra_ld_axi = 1'b1;
    
    S_CALC_START: begin
        input_weight_ren = 1'b1; 
        pe_start = 1'b1;
    end
    
    S_WAIT_READY: begin
        if (pe_done) begin
            ra_ld_acc = 1'b1;
            input_counter_ld = 1'b1;
        end
    end
    
    S_WRITE_TO_MEM: {axi_ram_ld, logic_wen, done} = 3'b111;
    S_WAIT_ACK:     {logic_wen, done} = {~start, start};
    endcase
end

endmodule