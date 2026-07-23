`include "hw_config.vh"

module cluster_ctrl(
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
    input input_counter_co

     );

localparam [2:0] S_IDLE = 0, S_LD_BETA = 1, S_WAIT_BETA = 2, S_WAIT_MEM = 3, S_CALCULATE = 4, S_WRITE_TO_MEM = 5, S_WAIT_ACK = 6;
reg [2:0] ps, ns;


always @(posedge clk) begin
    ps <= ns;
    if (!rstn)
        ps <= S_IDLE;
end

always @(*) begin
    ns = S_IDLE;
    case(ps)
    S_IDLE: ns = start ? S_LD_BETA : S_IDLE;
    S_LD_BETA: ns = S_CALCULATE;
    S_CALCULATE: ns = input_counter_co ? S_WRITE_TO_MEM : S_CALCULATE;
    S_WRITE_TO_MEM: ns = S_WAIT_ACK;
    S_WAIT_ACK: ns = ~start ? S_IDLE : S_WAIT_ACK;

    endcase

end

always @(*) begin
    {done, ra_ld_acc, input_weight_ren, ra_ld_axi,input_counter_clr,input_counter_ld, axi_ram_ld, logic_wen} = 0;
    case(ps)
    S_IDLE:{input_counter_clr} = 1'b1;
    S_LD_BETA: ra_ld_axi = 1'b1;
    S_CALCULATE: {input_weight_ren, ra_ld_acc, input_counter_ld} = 3'b111;
    S_WRITE_TO_MEM: {axi_ram_ld, logic_wen, done} = 3'b111;
    S_WAIT_ACK: {logic_wen ,done} = {~start, start};

    endcase

end

endmodule