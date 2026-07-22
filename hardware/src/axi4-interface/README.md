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

---

## 2. The Magic of `cocotbext-axi` (Why you don't see the signals in Python)
In standard Verilog testbenches, you would have to manually toggle `s00_axi_awvalid`, wait for `s00_axi_awready`, then send `s00_axi_wdata`, etc. 

Because we use the `cocotbext-axi` library in Python, the `AxiMaster` class handles all 5 channels and all handshakes automatically in the background. 
When you call `await axi_master.write(0x00, data)`, the library automatically:
1. Sends the address via the AW channel.
2. Sends the data via the W channel.
3. Waits for the B channel (response).
You never have to touch the individual AXI signals in Python. However, you must understand how the Verilog processes them.

---

## 3. Complete List of AXI Ports in Verilog
The `cluster_wrapper.v` module exposes three identical AXI4 Slave interfaces: `s00_axi` (Config), `s01_axi` (Input/Weight), and `s02_axi` (Register Array). 

Below is the complete list of AXI ports for **one** of these interfaces (e.g., `s00_axi`). The other two have the exact same structure, just prefixed with `s01_` and `s02_`.

### Global Signals
*   `s00_axi_aclk`: The clock driving this interface.
*   `s00_axi_aresetn`: Active-low reset (0 = reset, 1 = normal operation).

### Write Address (AW) Channel
*   `s00_axi_awid [11:0]`: ID tag for the write transaction (used for ordering).
*   `s00_axi_awaddr [...]`: The target address (e.g., `0x40000000` + offset).
*   `s00_axi_awlen [7:0]`: Burst length. Number of data beats to transfer (1 = single transfer, 4 = burst of 4).
*   `s00_axi_awsize [2:0]`: Size of each beat in bytes (e.g., `010` = 4 bytes/32 bits).
*   `s00_axi_awburst [1:0]`: Burst type (00=Fixed, 01=Incrementing, 10=Wrapping). *Our hardware expects Incrementing (01).*
*   `s00_axi_awlock`, `s00_axi_awcache`, `s00_axi_awprot`, `s00_axi_awqos`, `s00_axi_awregion`: Standard AXI attributes (mostly unused/ignored in our simple slave, but required by the protocol).
*   `s00_axi_awvalid`: Master says "Address is valid".
*   `s00_axi_awready`: Slave says "I am ready to receive the address".

### Write Data (W) Channel
*   `s00_axi_wdata [31:0]`: The 32-bit data payload.
*   `s00_axi_wstrb [3:0]`: Write Strobes. 1 bit per byte of `wdata`. Tells the slave which bytes are valid. (e.g., `1111` means all 4 bytes are written. `0011` means only the lower 2 bytes are written).
*   `s00_axi_wlast`: Master says "This is the last data beat in the burst".
*   `s00_axi_wvalid`: Master says "Data is valid".
*   `s00_axi_wready`: Slave says "I am ready to receive data".

### Write Response (B) Channel
*   `s00_axi_bresp [1:0]`: Response code (00=OKAY, 01=EXOKAY, 10=SLVERR, 11=DECERR). *Our hardware always returns OKAY (00).*
*   `s00_axi_bvalid`: Slave says "Response is valid".
*   `s00_axi_bready`: Master says "I am ready to receive the response".

### Read Address (AR) Channel
*   `s00_axi_arid [11:0]`: ID tag for the read transaction.
*   `s00_axi_araddr [...]`: The address to read from.
*   `s00_axi_arlen [7:0]`: Number of data beats to read.
*   `s00_axi_arsize [2:0]`: Size of each beat.
*   `s00_axi_arburst [1:0]`: Burst type.
*   `s00_axi_arlock`, `s00_axi_arcache`, ...: Attributes.
*   `s00_axi_arvalid`: Master says "Read address is valid".
*   `s00_axi_arready`: Slave says "I am ready to receive the read address".

### Read Data (R) Channel
*   `s00_axi_rdata [31:0]`: The 32-bit data read from the slave.
*   `s00_axi_rresp [1:0]`: Response code for the read.
*   `s00_axi_rlast`: Slave says "This is the last data beat".
*   `s00_axi_rvalid`: Slave says "Read data is valid".
*   `s00_axi_rready`: Master says "I am ready to receive the data".

---

## 4. How Our Hardware Uses These Ports (Interface by Interface)

### A. Config Interface (`s00_axi`) - Base: `0x40000000`
**Purpose:** Control and Status.
The Verilog `Axi4_config_mlp_v1_0_S00_AXI.v` implements a tiny 8-byte memory (`byte_ram`). 
*   **What we use:** We only use single-beat 32-bit writes and reads here. No bursts.
*   **Python interaction:**
    *   `axi_master_config.write(0x00, data)`: Sets the AW and W channels. The Verilog decodes the address, writes to `byte_ram`, and sends B response.
    *   `axi_master_config.read(0x04, 4)`: Sets the AR channel. Verilog reads `byte_ram`, sends R channel back to Python.

### B. Input/Weight Interface (`s01_axi`) - Base: `0x40001000`
**Purpose:** Load 8-bit data into the BRAMs.
The Verilog `Axi4_input_weight_brams_v1_0_S00_AXI.v` has a 1056-byte memory.
*   **What we use:** We send arrays of 32 bytes at a time. `cocotbext-axi` automatically turns this into an AXI Burst (AWLEN > 0). 
*   **How Verilog handles it:** The AXI data bus is 32 bits wide (`s01_axi_wdata`). But our hardware memory is 8 bits wide (`byte_ram`). The Verilog code uses a `for` loop and the `WSTRB` signal to split the 32-bit word into four 8-bit words and writes them to consecutive memory addresses.
*   **Python interaction:**
    *   `axi_master_iwb.write(addr, 32_byte_array)`: Python sends a burst. Verilog receives 8 beats of 32-bit data (8 * 4 = 32 bytes). Verilog unpacks them into 32 separate 8-bit memory locations.

### C. Register Array Interface (`s02_axi`) - Base: `0x40002000`
**Purpose:** 32-bit Accumulators (Bias in, Output out).
The Verilog `Axi4_register_array_v1_0_S00_AXI.v` has a 128-byte memory.
*   **What we use:** We send 32-bit integers.
*   **How Verilog handles it:** Similar to above, but the memory is 32 bits wide, so it maps 1:1 to the AXI data bus. No complex byte packing is needed.
*   **Python interaction:**
    *   `axi_master_ra.write(0x00, bias_data.tobytes())`: Sends the 32-bit bias values.
    *   `axi_master_ra.read(0x00, 128)`: Reads all 32 output registers.

---

## 5. The Hardware FSM & The `logic_wen` Signal
There is one special internal signal you should know about: **`logic_wen`**.
When the hardware FSM (`cluster_ctrl.v`) is busy calculating, it sets `logic_wen = 1`. 
Inside the Config AXI Slave, this signal is used to **block** the host from writing new configurations while the hardware is running. 
Furthermore, when the hardware finishes, it forces `byte_ram[6][0] <= done` *only* if `logic_wen` is 1. This prevents race conditions between the host writing and the hardware updating the `done` flag.

***

### Summary for the Python Developer
You do not need to worry about `VALID`, `READY`, `AWLEN`, or `WSTRB`. The `cocotbext-axi` library handles all of this. 

Your only job is to know:
1. **Which base address to target** (`0x40000000`, `0x40001000`, `0x40002000`).
2. **What offset to use** (`0x00` for data, `0x04` for config/done, etc.).
3. **How to pack your data** (using NumPy `tobytes()` with correct data types like `uint8` or `int32`).
