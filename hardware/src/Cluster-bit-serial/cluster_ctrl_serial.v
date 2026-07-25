`define MAX_INPUT_SIZE 32 // aka I0
`define MAX_PES 32 // aka O0


`define INPUT_D_W 8 // input data width
`define PE_A_W $clog2(`MAX_PES)
`define PE_D_W 32 // max(clog2(input_size), clog2(max_PEs))


`define WEIGHT_MEM_DEPTH `MAX_INPUT_SIZE
`define WEIGHT_MEM_A_W $clog2(`MAX_INPUT_SIZE) // weight memory address width
`define WEIGHT_MEM_D_W 8 // weight memory data width

`define INPUT_ZP_WIDTH 8

`define INPUT_NUM_WIDTH 16
`define OUTPUT_NUM_WIDTH 16


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
    output reg [2:0] bit_index // سیگنال جدید: شماره بیت ورودی برای دیتاپث
);

localparam [2:0] S_IDLE = 0, S_LD_BETA = 1, S_WAIT_BETA = 2, S_WAIT_MEM = 3, S_CALCULATE = 4, S_WRITE_TO_MEM = 5, S_WAIT_ACK = 6;
reg [2:0] ps, ns;

// شمارنده ۳ بیتی برای ۸ سیکل پردازش بیت‌سریال
reg [2:0] bit_counter;

always @(posedge clk) begin
    ps <= ns;
    if (!rstn) begin
        ps <= S_IDLE;
        bit_counter <= 0;
    end else if (ps == S_CALCULATE) begin
        if (bit_counter == 3'd7)
            bit_counter <= 0;
        else
            bit_counter <= bit_counter + 1;
    end else begin
        bit_counter <= 0;
    end
end

// ارسال شماره بیت به دیتاپث
assign bit_index = bit_counter;

always @(*) begin
    ns = S_IDLE;
    case(ps)
    S_IDLE: ns = start ? S_LD_BETA : S_IDLE;
    S_LD_BETA: ns = S_CALCULATE;
    // تنها زمانی از حالت محاسبه خارج می‌شویم که هم ورودی‌ها تمام شده باشند و هم ۸ سیکل کامل شده باشد
    S_CALCULATE: ns = (input_counter_co && (bit_counter == 3'd7)) ? S_WRITE_TO_MEM : S_CALCULATE;
    S_WRITE_TO_MEM: ns = S_WAIT_ACK;
    S_WAIT_ACK: ns = ~start ? S_IDLE : S_WAIT_ACK;
    endcase
end

always @(*) begin
    {done, ra_ld_acc, input_weight_ren, ra_ld_axi, input_counter_clr, input_counter_ld, axi_ram_ld, logic_wen} = 0;
    case(ps)
    S_IDLE: {input_counter_clr} = 1'b1;
    S_LD_BETA: ra_ld_axi = 1'b1;
    S_CALCULATE: begin
        input_weight_ren = 1'b1; // حافظه را نگه می‌داریم تا ۸ سیکل تمام شود
        ra_ld_acc = 1'b1;        // انباشتگر در هر سیکل آپدیت می‌شود
        if (bit_counter == 3'd7)
            input_counter_ld = 1'b1; // پس از ۸ سیکل، آدرس ورودی بعدی تولید شود
    end
    S_WRITE_TO_MEM: {axi_ram_ld, logic_wen, done} = 3'b111;
    S_WAIT_ACK: {logic_wen, done} = {~start, start};
    endcase
end

endmodule