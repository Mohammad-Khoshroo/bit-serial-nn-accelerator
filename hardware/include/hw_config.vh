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

