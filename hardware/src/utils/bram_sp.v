// Block RAM with Resettable Data Output
// File: brams_sp.v
module bram_sp #(
    parameter integer DATA_WIDTH = 8,
    parameter integer DATA_LEN = 64,
    parameter integer ADDR_WIDTH = $clog2(DATA_LEN)
    ) (
    input clk,
    input en,
    input we,
    input [ADDR_WIDTH - 1 : 0] addr,
    input [DATA_WIDTH - 1 : 0] di,
    output reg [DATA_WIDTH - 1 : 0] dout);
    

    reg [DATA_WIDTH - 1 : 0] ram [DATA_LEN - 1:0];

    always @(posedge clk) begin
        if (en) begin
            if (we) //write enable
                ram[addr] <= di;
            else
                dout <= ram[addr];
        end
    end

endmodule