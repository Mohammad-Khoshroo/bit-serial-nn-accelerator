
module mul_add #(
    parameter integer A_WIDTH = 8,
    parameter integer B_WIDTH = 8,
    parameter integer C_WIDTH = 24,
    parameter integer O_WIDTH = 24
) (
    input clk, rstn,
    input en, clear,
    input signed [A_WIDTH-1 : 0] mul_a,
    input signed [B_WIDTH-1 : 0] mul_b,
    input signed [C_WIDTH-1 : 0] add_c,
    output reg signed [O_WIDTH-1 : 0] out
    );
    
    reg signed [O_WIDTH - 1 : 0] mult_res;
    
    always @(posedge clk) begin
        if (en) begin
            mult_res <= mul_a * mul_b;
            out <= mult_res + out;
        end
        if (clear | !rstn) begin
            mult_res <= 0;
            out <= 0;
        end
    end


endmodule