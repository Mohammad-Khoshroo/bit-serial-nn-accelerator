# AXI4 Interface Architecture & Protocol

## 1. Overview: What is AXI4?
AXI4 (Advanced eXtensible Interface) is a protocol for communication between IP blocks in an FPGA/SoC. It is **memory-mapped**, meaning the Master (our Python Cocotb script) reads and writes to specific addresses, and the Slave (our Verilog hardware) reacts to those addresses.

The protocol uses **5 independent channels**. Every transaction (read or write) uses a combination of these channels:
1. **Write Address (AW):** "I want to write to this address."
2. **Write Data (W):** "Here is the data."
3. **Write Response (B):** "I received your write successfully."
4. **Read Address (AR):** "I want to read from this address."
5. **Read Data (R):** "Here is the data you asked for."

Every signal in these channels ends with `VALID` and `READY`. This is the **Handshake** mechanism. Data only transfers when *both* `VALID` and `READY` are `1` on the same clock cycle.

## 2. The Magic of `cocotbext-axi` (Why you don't see the signals in Python)
In standard Verilog testbenches, you would have to manually toggle `s00_axi_awvalid`, wait for `s00_axi_awready`, then send `s00_axi_wdata`, etc. 

Because we use the `cocotbext-axi` library in Python, the `AxiMaster` class handles all 5 channels and all handshakes automatically in the background. 
When you call `await axi_master.write(0x00, data)`, the library automatically:
1. Sends the address via the AW channel.
2. Sends the data via the W channel.
3. Waits for the B channel (response).
You never have to touch the individual AXI signals in Python. However, you must understand how the Verilog processes them.

## 3. Standard AXI Protocol vs. Custom Hardware Mapping (CRITICAL)
It is crucial to understand the difference between the AXI standard and the memory addresses we use in Python:

*   **What AXI Defines:** The AXI standard *only* defines the **"How" (Protocol)**. It dictates the existence of AW, W, B, AR, R channels, the `VALID`/`READY` handshakes, and the data bus width (e.g., 32-bit). **AXI has no idea what address `0x40000000` means.** For AXI, an address is just a number; it doesn't care if it points to a RAM, a register, or an LED.
*   **What Our Verilog Defines:** The addresses, base offsets, and memory sizes are **Custom (Hardcoded)** by the hardware designer in the Verilog files. When Python sends a packet to `0x40000004`, the AXI bus just delivers it. The Verilog code inside the slave module uses `if` conditions or address decoding logic to decide: *"If the address is 0x04, put this data into `byte_ram[1]` and route it to the `input_zp` signal."*

Because these addresses are custom, the Python driver **must** be perfectly synchronized with the Verilog logic. If the Verilog designer changes the `done` flag from offset `0x04` to `0x10`, the Python code must be updated accordingly.

---

## 4. Complete List of AXI Ports in Verilog
The `cluster_wrapper.v` module exposes three identical AXI4 Slave interfaces: `s00_axi` (Config), `s01_axi` (Input/Weight), and `s02_axi` (Register Array). 

Below is the complete list of AXI ports for **one** of these interfaces (e.g., `s00_axi`). The other two have the exact same structure, just prefixed with `s01_` and `s02_`.

### Global Signals
*   `s00_axi_aclk`: The clock driving this interface.
*   `s00_axi_aresetn`: Active-low reset (0 = reset, 1 = normal operation).

### Write Address (AW) Channel
*   `s00_axi_awid [11:0]`: ID tag for the write transaction.
*   `s00_axi_awaddr [...]`: The target address.
*   `s00_axi_awlen [7:0]`: Burst length. Number of data beats to transfer.
*   `s00_axi_awsize [2:0]`: Size of each beat in bytes (e.g., `010` = 4 bytes/32 bits).
*   `s00_axi_awburst [1:0]`: Burst type (01=Incrementing). *Our hardware expects this.*
*   `s00_axi_awlock`, `s00_axi_awcache`, `s00_axi_awprot`, `s00_axi_awqos`, `s00_axi_awregion`: Standard AXI attributes (ignored by our simple slave).
*   `s00_axi_awvalid`: Master says "Address is valid".
*   `s00_axi_awready`: Slave says "I am ready to receive the address".

### Write Data (W) Channel
*   `s00_axi_wdata [31:0]`: The 32-bit data payload.
*   `s00_axi_wstrb [3:0]`: Write Strobes. 1 bit per byte of `wdata`. Tells the slave which bytes are valid.
*   `s00_axi_wlast`: Master says "This is the last data beat in the burst".
*   `s00_axi_wvalid`: Master says "Data is valid".
*   `s00_axi_wready`: Slave says "I am ready to receive data".

### Write Response (B) Channel
*   `s00_axi_bresp [1:0]`: Response code (00=OKAY). *Our hardware always returns OKAY.*
*   `s00_axi_bvalid`: Slave says "Response is valid".
*   `s00_axi_bready`: Master says "I am ready to receive the response".

### Read Address (AR) Channel
*   `s00_axi_arid [11:0]`: ID tag for the read transaction.
*   `s00_axi_araddr [...]`: The address to read from.
*   `s00_axi_arlen [7:0]`: Number of data beats to read.
*   `s00_axi_arsize [2:0]`: Size of each beat.
*   `s00_axi_arburst [1:0]`: Burst type.
*   `s00_axi_arvalid`: Master says "Read address is valid".
*   `s00_axi_arready`: Slave says "I am ready to receive the read address".

### Read Data (R) Channel
*   `s00_axi_rdata [31:0]`: The 32-bit data read from the slave.
*   `s00_axi_rresp [1:0]`: Response code for the read.
*   `s00_axi_rlast`: Slave says "This is the last data beat".
*   `s00_axi_rvalid`: Slave says "Read data is valid".
*   `s00_axi_rready`: Master says "I am ready to receive the data".

---

## 5. How Our Hardware Uses These Ports (Verilog Proofs)

### A. Config Interface (`s00_axi`) - Base: `0x40000000`
**Purpose:** Control and Status.
The Verilog implements a tiny 8-byte memory (`byte_ram`). The AXI bus writes 32-bit words to this memory. The Verilog then maps specific bytes of this memory to actual control signals.

**Verilog Proof (Address to Signal Mapping):**
```verilog
// From Axi4_config_mlp_v1_0_S00_AXI.v
// The AXI bus writes to byte_ram. These lines map byte_ram to actual logic signals:

assign start      = byte_ram[0][0];                     // Offset 0x00, bit 0
assign input_zp   = byte_ram[1];                        // Offset 0x00, byte 1 (or viewed as 0x04 in 32-bit steps)
assign input_num  = {byte_ram[3], byte_ram[2]};         // Offset 0x08 (bytes 2 and 3)
assign output_num = {byte_ram[5], byte_ram[4]};         // Offset 0x0C (bytes 4 and 5)

// Hardware writes 'done' back to byte_ram[6][0] (Offset 0x10, bit 0)
always @( posedge S_AXI_ACLK ) begin
    if (logic_wen) begin
        byte_ram[6][0] <= done; 
    end
end
```
*   **Python interaction:** We write a 32-bit word to `0x00` containing `start`, `input_zp`, and `input_num`. We read `0x04` (which contains byte 6) to check the `done` flag. Wait, note that in Python we read offset `0x04` and shift by 16 bits. This is because `0x04` in a 32-bit bus fetches bytes 4,5,6,7. Byte 6 is at bit 16 of that 32-bit word.

### B. Input/Weight Interface (`s01_axi`) - Base: `0x40001000`
**Purpose:** Load 8-bit data into the BRAMs.
The Verilog has a 1056-byte memory. The AXI bus is 32-bit, so it sends 4 bytes at a time. The Verilog uses the `WSTRB` (Write Strobes) and address increments to split the 32-bit word into four 8-bit words.

**Verilog Proof (Burst Unpacking & Memory Layout):**
```verilog
// From Axi4_input_weight_brams_v1_0_S00_AXI.v
reg  [8-1:0] byte_ram [0 : BLOCK_NUM * BLOCK_SIZE - 1]; // 1056 bytes total

// AXI 32-bit write split into 8-bit writes
always @( posedge S_AXI_ACLK ) begin
    if (mem_wren) begin
        for(mem_byte_index_i=0; mem_byte_index_i<= 3; mem_byte_index_i=mem_byte_index_i+1) begin
            if ( S_AXI_WSTRB[mem_byte_index_i[1:0]]) begin
                byte_ram[{mem_address, mem_byte_index_i[1:0]}] <= S_AXI_WDATA[(mem_byte_index_i[1:0]*8+7) -: 8];
            end
        end
    end
end

// Internal hardware reading logic
// Block 0 (addr 0-31) is input. Blocks 1-32 are weights.
always @(posedge S_AXI_ACLK) begin
    if (input_weight_ren) begin
        input_data <= byte_ram[input_weight_address]; // Read input
    end
end
generate
    for (nw = 1; nw <= MAX_PES; nw = nw + 1) begin
        always @(posedge S_AXI_ACLK) begin
            if (input_weight_ren) begin
                // Read weight for PE 'nw'. Address math: nw * 32 + input_weight_address
                weight_data[nw*WEIGHT_DATA_WIDTH - 1 -: WEIGHT_DATA_WIDTH] <= byte_ram[{nw[$clog2(MAX_PES) : 0], input_weight_address}]; 
            end
        end
    end	
endgenerate
```
*   **Python interaction:** We send a 32-byte array to `0x0000`. Python AXI Master splits this into 8 bursts of 32-bit words. Verilog unpacks them into `byte_ram[0]` to `byte_ram[31]`. Then we send weights to offset `0x020` (decimal 32), which Verilog maps to PE 0.

### C. Register Array Interface (`s02_axi`) - Base: `0x40002000`
**Purpose:** 32-bit Accumulators (Bias in, Output out).
The Verilog has a 128-byte memory. Because the data is 32-bit, it maps 1:1 to the AXI bus without needing `WSTRB` splitting.

**Verilog Proof (Bias Loading & Output Dumping):**
```verilog
// From Axi4_register_array_v1_0_S00_AXI.v
reg  [8-1:0] byte_ram [0 : BYTE_REG_NUM - 1]; // 128 bytes (32 x 32-bit)

// Load bias from BRAM to internal accumulators when controller says so
always @(posedge ra_clk) begin
    if (ra_ld_axi) begin
        register_array[i * 8 +: 8] <= byte_ram[i];
    end
    // Accumulate MAC results internally
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
*   **Python interaction:** We write 128 bytes of bias data to `0x0000`. When the hardware finishes, it sets `axi_ram_ld` to copy the internal accumulators into this BRAM. We then read 128 bytes from `0x0000` to get the results.

## 6. The Hardware FSM & The `logic_wen` Signal
There is one special internal signal you should know about: **`logic_wen`**.

When the hardware FSM (`cluster_ctrl.v`) is busy calculating, it sets `logic_wen = 1`. 

Inside the Config AXI Slave, this signal is used to **block** the host from writing new configurations while the hardware is running. 

Furthermore, when the hardware finishes, it forces `byte_ram[6][0] <= done` *only* if `logic_wen` is 1. This prevents race conditions between the host writing and the hardware updating the `done` flag.

## 7. Where are the Base Addresses Defined? (Physical Board vs. Cocotb)

A common source of confusion is where the absolute base addresses (like `0x40000000`) come from, and whether they actually matter in our simulation.

### A. On the Physical Board (Vivado / Zynq ARM)
In the real physical system, the hardware does not know its absolute base address. The AXI slave modules only define the *address width* and process **relative offsets**. 
The absolute base addresses are assigned by the system architect in Vivado's Block Design using TCL scripts. An **AXI Interconnect** (a routing chip) sits between the ARM processor and the accelerator.

**Proof from the Vivado Block Design Script (`bd/7000.tcl`):**
```tcl
# The processing_system7_0 (ARM CPU) maps the cluster_wrapper's AXI ports to specific addresses:

# s00_axi (Config) is mapped to 0x40000000 with a 4KB range
assign_bd_address -offset 0x40000000 -range 0x00001000 \
    -target_address_space [get_bd_addr_spaces processing_system7_0/Data] \
    [get_bd_addr_segs cluster_wrapper/s00_axi/reg0] -force

# s01_axi (Input/Weight) is mapped to 0x40001000
# s02_axi (Register Array) is mapped to 0x40002000
```
When the ARM processor writes to `0x40000004`, the AXI Interconnect sees the base address, routes the packet to `s00_axi`, and passes only the offset (`0x04`) to the Verilog module.

### B. In Our Cocotb Simulation (The "Dummy" Base Addresses)
In our Python simulation, **there is no ARM processor and no AXI Interconnect.** 

In `system.py`, we create three distinct `AxiMaster` objects, and each one is hardwired **directly** to the specific Verilog port:
```python
self.axi_master_config = AxiMaster(AxiBus.from_prefix(dut, "s00_axi"), ...)
self.axi_master_iwb    = AxiMaster(AxiBus.from_prefix(dut, "s01_axi"), ...)
self.axi_master_ra     = AxiMaster(AxiBus.from_prefix(dut, "s02_axi"), ...)
```

Because the connections are direct, **the base addresses (`0x40000000`, etc.) are completely "Dummy" (unused) in Cocotb.** 
When you call:
```python
await self.axi_master_config.write(0x04, data)
```
The Cocotb library puts the value `0x04` directly onto the `s00_axi_awaddr` wires. The `0x40000000` part is entirely ignored. The Verilog module receives `0x04` and writes to its internal `byte_ram`.

**Why do we keep them in the code?**
We keep the base addresses in our Python dictionaries (like `HwConfig`) purely as "labels" to mimic the real system's memory map and keep the code structurally similar to the C driver (`driver.c`) for easier debugging. But functionally, the simulator only cares about the offsets (`0x00`, `0x04`, `0x08`, etc.)!


## 8. Addressing Summary from the Python Developer's Perspective

To conclude the addressing behavior in our specific Cocotb setup:

1.  **No Base Addresses Needed:** In our Python testbench, we explicitly instantiate a separate `AxiMaster` object for each AXI interface (`s00_axi`, `s01_axi`, `s02_axi`). Because the routing is hardcoded by these objects connecting directly to the Verilog ports, we bypass the need for AXI Interconnect routing. Therefore, base addresses like `0x40000000` are completely irrelevant in the simulation.
2.  **Verilog Only Sees Offsets:** The Verilog AXI Slave modules do not evaluate absolute addresses. They are designed to decode only the lower bits (relative offsets). When Python sends an address, the Verilog simply uses it to index into its local `byte_ram` array.
3.  **The Developer's Only Job:** To interact with the hardware, the Python developer only needs to know two things:
    *   **Which interface** to target (e.g., `axi_master_config` vs `axi_master_iwb`).
    *   **What offset** to use for that specific interface (e.g., `0x00` for start, `0x20` for PE 0's weights).
