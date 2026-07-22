# Hardware Architecture

## 1. Overview
This directory contains the RTL (Verilog) source code for a **Bit-Parallel Neural Network Accelerator**. The architecture is based on an **Output Stationary** dataflow, where each Processing Element (PE) computes and accumulates one output neuron. The system is wrapped with three AXI4 interfaces for communication with a host (or a Cocotb testbench).

## 2. Directory Structure & File Hierarchy
```
hardware/
├── include/
│   └── hw_config.vh          # Global parameters and macros
└── src/
    ├── Cluster/               # Core computation logic (Datapath & Controller)
    │   ├── cluster_top.v
    │   ├── cluster_ctrl.v
    │   └── cluster_dp.v
    ├── Cluster-wrapper/
    │   └── cluster_wrapper.v  # Top-level: connects Cluster to AXI interfaces
    ├── axi4-interface/        # AXI4 Slave modules (Memory-mapped)
    │   ├── config/            # Control & Status registers
    │   ├── input-weight-rams/ # BRAMs for inputs and weights
    │   └── register-array/    # BRAM for bias and output accumulators
    └── utils/                 # Helper modules (BRAM, MAC)
```

The hardware is structured in a strict top-down hierarchy. When running the simulation, the testbench (Cocotb) connects to the `cluster_wrapper` module, and data flows down through the AXI wrappers to the core compute logic.

### Module Instantiation Tree
```text
cluster_wrapper.v  (Top Level: Exposes AXI ports to Cocotb/Host)
│
├── Axi4_config_cluster_v1_0.v          (Config AXI Wrapper)
│   └── Axi4_config_cluster_v1_0_S00_AXI.v (Config AXI Logic & Registers)
│
├── Axi4_input_weight_brams_v1_0.v      (Input/Weight AXI Wrapper)
│   └── Axi4_input_weight_brams_v1_0_S00_AXI.v (Input/Weight AXI Logic & BRAMs)
│
├── Axi4_register_array_v1_0.v          (Accumulator AXI Wrapper)
│   └── Axi4_register_array_v1_0_S00_AXI.v (Accumulator AXI Logic & BRAM)
│
└── cluster_top.v                       (Core Compute Wrapper)
    ├── cluster_ctrl.v                  (FSM Controller)
    └── cluster_dp.v                    (Datapath / MAC operations)
```

### Vivado IP File Pattern (`_v1_0.v` vs `_v1_0_S00_AXI.v`)
Inside the `axi4-interface` subdirectories, you will notice pairs of files for each AXI port. This follows the standard Xilinx Vivado Custom IP pattern:
*   **`*_v1_0.v` (Wrapper):** This is the top-level shell of the IP. It is instantiated by `cluster_wrapper.v`. It contains no logic. Its only job is to map the standard AXI ports to the implementation module.
*   **`*_v1_0_S00_AXI.v` (Implementation):** This is the actual "brain" of the AXI interface. It is instantiated by the Wrapper. It contains all the AXI Finite State Machines (handshake, burst, address decoding) and the internal memories (`byte_ram`). 
*   **Note:** Both files are strictly required for the simulator to compile the design. However, when you need to check memory addresses, offsets, or how data is stored, you only need to read the `_S00_AXI.v` file.

## 3. System Configuration (`include/hw_config.vh`)
The hardware is parameterized using Verilog macros.
```verilog
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
```

## 4. AXI Interfaces & Memory Map (Implementation Details)
The host interacts with the accelerator via three independent AXI4 Slave interfaces exposed by `cluster_wrapper.v`.

### A. Config Interface (`s00_axi`)
Base Address: `0x40000000` | Size: 8 Bytes
Used to start the engine, set parameters, and check for completion. The logic resides in `Axi4_config_mlp_v1_0_S00_AXI.v`.
*   **Offset `0x00`**: `[0]` = `start` (Write 1 to start).
*   **Offset `0x04`**: `input_zp` (8-bit input zero point).
*   **Offset `0x08`**: `input_num` (16-bit, actual number of inputs $\le 32$).
*   **Offset `0x0C`**: `output_num` (16-bit, actual number of outputs $\le 32$).
*   **Offset `0x10`**: `[0]` = `done` (Read-only. Set to 1 by hardware when finished).

**Verilog Logic Excerpt:**
```verilog
// From Axi4_config_mlp_v1_0_S00_AXI.v
assign start = byte_ram[0][0];
assign input_zp = byte_ram[1];
assign input_num = {byte_ram[3], byte_ram[2]};
assign output_num = {byte_ram[5], byte_ram[4]};

always @( posedge S_AXI_ACLK ) begin
    if (mem_wren & (~logic_wen)) begin
        // ... write logic for byte_ram ...
    end else if (logic_wen) begin
        byte_ram[6][0] <= done; // Hardware updates 'done' flag at offset 0x10
    end
end
```

### B. Input/Weight BRAMs (`s01_axi`)
Base Address: `0x40001000` | Size: 1056 Bytes
Holds the input vector and the weight matrix. Logic resides in `Axi4_input_weight_brams_v1_0_S00_AXI.v`.
*   **Block 0 (`0x000` to `0x01F`)**: 32 Input data (8-bit each).
*   **Block 1 (`0x020` to `0x03F`)**: 32 Weights for PE 0.
*   ...up to Block 32 for PE 31.

**Verilog Logic Excerpt:**
```verilog
// From Axi4_input_weight_brams_v1_0_S00_AXI.v
// Reading data internally when cluster requests it
always @(posedge S_AXI_ACLK) begin
    if (input_weight_ren) begin
        input_data <= byte_ram[input_weight_address];
    end
end

genvar nw;
generate
    for (nw = 1; nw <= MAX_PES; nw = nw + 1) begin
        always @(posedge S_AXI_ACLK) begin
            if (input_weight_ren) begin
                // Fetch weight for PE 'nw' at 'input_weight_address'
                weight_data[nw*WEIGHT_DATA_WIDTH - 1 -: WEIGHT_DATA_WIDTH] <= byte_ram[{nw[$clog2(MAX_PES) : 0], input_weight_address}]; 
            end
        end
    end	
endgenerate
```

### C. Register Array / Accumulators (`s02_axi`)
Base Address: `0x40002000` | Size: 128 Bytes (32 x 32-bit)
Used to initialize accumulators with bias and read final results. Logic resides in `Axi4_register_array_v1_0_S00_AXI.v`.

**Verilog Logic Excerpt:**
```verilog
// From Axi4_register_array_v1_0_S00_AXI.v
// Load bias from BRAM to internal accumulators
always @(posedge ra_clk) begin
    if (ra_ld_axi) begin
        register_array[i * 8 +: 8] <= byte_ram[i];
    end
    // Accumulate MAC results
    else if (ra_ld_acc) begin
        register_array[i * 8 +: 8] <= ra_in_acc[i * 8 +: 8];
    end
end

// Dump internal accumulators back to BRAM for host to read
always @( posedge S_AXI_ACLK ) begin
    else if (axi_ram_ld) begin
        byte_ram[axi_ram_i] <= register_array[axi_ram_i * 8 +: 8];
    end	
end
```

## 5. Core Architecture (`Cluster`)

### `cluster_ctrl.v` (Control FSM)
A simple Finite State Machine (FSM) orchestrates the data flow.

**Verilog Code:**
```verilog
module cluster_ctrl(
    input clk, input rstn, input start,
    output reg logic_wen, output reg done,
    output reg ra_ld_axi, output reg ra_ld_acc, output reg axi_ram_ld,
    output reg input_weight_ren, output reg input_counter_clr, output reg input_counter_ld,
    input input_counter_co
);

localparam [2:0] S_IDLE = 0, S_LD_BETA = 1, S_WAIT_BETA = 2, S_WAIT_MEM = 3, 
                 S_CALCULATE = 4, S_WRITE_TO_MEM = 5, S_WAIT_ACK = 6;
reg [2:0] ps, ns;

always @(posedge clk) begin
    ps <= ns;
    if (!rstn) ps <= S_IDLE;
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
```

### `cluster_dp.v` (Datapath)
Contains the arithmetic logic. For every clock cycle in `S_CALCULATE`, it reads `input_data` and `weight_data`, and computes the MAC operation.

**Verilog Code:**
```verilog
module cluster_dp #( /* parameters */ ) (
    input clk, rstn,
    input [$clog2(MAX_INPUT_SIZE) - 1 : 0] input_size,
    input [$clog2(MAX_PES) - 1 : 0] output_size,
    input [INPUT_D_W - 1 : 0] input_data,
    input signed [WEIGHT_MEM_D_W * MAX_PES - 1 : 0] weight_data,
    output [ INPUT_WEIGHT_ADDR_WIDTH - 1 : 0 ] input_weight_address,
    input input_counter_clr, input input_counter_ld, output input_counter_co,
    input [`INPUT_ZP_WIDTH-1:0] input_zp,
    output reg [BYTE_REG_NUM * 8-1:0] ra_in_acc,
    input [BYTE_REG_NUM * 8-1:0] register_array
);
    
// Counter for iterating over inputs
reg [INPUT_WEIGHT_ADDR_WIDTH-1 : 0] input_counter_r;
always @(posedge clk) begin
    if(input_counter_ld) input_counter_r <= input_counter_r + 1;
    if (input_counter_clr | !rstn) input_counter_r <= 0; 
end
assign input_counter_co = input_counter_r >= input_size;
assign input_weight_address = input_counter_r;

// Subtract input zero point
wire signed [ 8 : 0] input_signed; 
assign input_signed = input_data - input_zp;

// Parallel MAC operations for all PEs
genvar k;
generate
    for (k = 0; k < MAX_PES; k = k + 1) begin
        wire signed [PE_D_W - 1 : 0] ra_mat_temp;
        wire signed [PE_D_W - 1 : 0] ra_in;
        reg [PE_D_W - 1 : 0] ra_out;
        
        // Extract weight for PE k
        reg signed [WEIGHT_MEM_D_W - 1 : 0] weight_data_i;
        always @(*) begin
            ra_out[k] = register_array[(k) * PE_D_W +: PE_D_W];
            ra_in_acc[(k) * PE_D_W +: PE_D_W] = ra_in[k];
            weight_data_i[k] = weight_data[(k) * WEIGHT_MEM_D_W +: WEIGHT_MEM_D_W];
        end
        
        // Bit-Parallel Multiplication and Accumulation
        assign ra_mat_temp[k] = input_signed * weight_data_i[k];
        assign ra_in[k] = ra_out[k] + ra_mat_temp[k]; 
    end
endgenerate
endmodule
```

## 6. Execution Flow (Host Perspective)
To execute a layer operation, the host (Cocotb) must follow this exact sequence:
1.  **Write Bias**: Send 32x32-bit bias values to `s02_axi` (`0x40002000`).
2.  **Write Data**: Send up to 32 input values to `s01_axi` (`0x40001000`, Block 0).
3.  **Write Weights**: Send up to 32x32 weight values to `s01_axi` (`0x40001000`, Blocks 1-32).
4.  **Configure**: Write `input_zp`, `input_num`, and `output_num` to `s00_axi` (`0x40000004`, `0x08`, `0x0C`).
5.  **Start**: Write `1` to `s00_axi` offset `0x00` (`start` bit).
6.  **Poll**: Read `s00_axi` offset `0x10` until bit `[0]` is `1` (`done`).
7.  **Clear Start**: Write `0` to `s00_axi` offset `0x00` to acknowledge completion.
8.  **Read Output**: Read 32x32-bit output values from `s02_axi` (`0x40002000`).

## 7. Utilities (`utils/`)
*   `bram_sp.v`: A standard single-port Block RAM wrapper.
*   `mull_add.v`: A pipelined Multiply-and-Accumulate (MAC) module. While the current `cluster_dp.v` uses inline Verilog multiplication (`*`), this module represents the logic that will be targeted for the Bit-Serial optimization in Phase 2 of the project.

```verilog
// mull_add.v
module mul_add #( /* parameters */ ) (
    input clk, rstn, input en, clear,
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
            mult_res <= 0; out <= 0;
        end
    end
endmodule
```