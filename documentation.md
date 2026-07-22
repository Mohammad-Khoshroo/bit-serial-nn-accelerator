# Cocotb Driver Architecture & Implementation

## 1. Overview
In the physical board, an ARM processor runs C code (`LLRT/driver.c`) to communicate with the FPGA accelerator via AXI4. In our simulation environment, we replace the ARM processor with a Python script using **Cocotb** and **cocotbext-axi**. 

The `accel_driver` class in `src/system.py` is the direct Python equivalent of the C driver. It handles memory mapping, data packing, and AXI transactions.

## 2. Hardware Configuration Mirroring (`HwConfig`)
Verilog parameters (macros from `hw_config.vh`) are evaluated at compile-time. Since Cocotb runs at runtime, it cannot read Verilog macros directly. To keep the Python code synchronized with the hardware without hardcoding numbers everywhere, a mirror configuration class is used:

```python
class HwConfig:
    MAX_INPUT_SIZE = 32  # Mirror of I0 in hw_config.vh
    MAX_PES = 32         # Mirror of O0 in hw_config.vh
```
If the hardware dimensions change, only this class needs to be updated in Python.

## 3. AXI Memory Map
The driver interacts with three AXI4 Slave interfaces exposed by `cluster_wrapper.v`.

| Interface | AXI Port | Base Address | Size | Purpose |
| :--- | :--- | :--- | :--- | :--- |
| **Config** | `s00_axi` | `0x40000000` | 8 Bytes | Control registers (start, done, zp, sizes) |
| **Input/Weight** | `s01_axi` | `0x40001000` | 1056 Bytes | BRAM for inputs and weights |
| **Register Array**| `s02_axi` | `0x40002000` | 128 Bytes | BRAM for bias (in) and output (out) |

## 4. Driver Methods & Hardware Mapping

### A. `bias_setup(bias_tile, o0)`
**Goal:** Write initial bias values into the Accumulator BRAM.
*   **Hardware Target:** `s02_axi` (`0x40002000`).
*   **Logic:** The hardware has 32 accumulators (32-bit each). We create a 32-element `int32` NumPy array, fill the first `o0` elements with bias, and write the raw bytes to offset `0x00`.

### B. `hw_setup(input_tile, weight_tile, input_zp, i0, o0)`
**Goal:** Send data, configure the engine, start, and wait for completion.
*   **Hardware Target:** `s01_axi` and `s00_axi`.
*   **Logic:**
    1.  **Write Inputs:** Pack `i0` inputs into a 32-element `uint8` array. Write to `s01_axi` offset `0x00` (Block 0).
    2.  **Write Weights:** For each PE `k` (from 0 to `o0-1`), pack 32 weights into a `uint8` array. Write to offset `(k + 1) * 32`. This matches the Verilog BRAM layout where Block `k` holds weights for PE `k-1`.
    3.  **Configure Output Num:** Write `(o0 - 1)` to `s00_axi` offset `0x04`.
    4.  **Configure Start/Input:** Construct a 32-bit word: `[input_num (16b)][input_zp (8b)][start (1b)]`. Write to `s00_axi` offset `0x00`.
    5.  **Poll for Done:** Read `s00_axi` offset `0x04`. The `done` flag is at bit 16 (which corresponds to byte 6 in the Verilog `byte_ram`). Loop until it is `1`.
    6.  **Clear Start:** Write `0` to `s00_axi` offset `0x00` to return the FSM to `S_IDLE`.

### C. `recv_output(o0)`
**Goal:** Read the computed MAC results.
*   **Hardware Target:** `s02_axi` (`0x40002000`).
*   **Logic:** Read 128 bytes (32 x 32-bit words) from offset `0x00`. Convert the bytes back into an `int32` NumPy array and return the first `o0` elements.

## 5. C-to-Python Translation Evidence
The Python implementation strictly follows the logic of `src/LLRT/driver/driver.c`.

**Register Configuration (C vs Python):**
```c
// C Code (driver.c)
config_data = ((input_zp & 0xFF) << 8) | (((i0 - 1) & 0xFFFF) << 16) | 1;
eaiot_hal_Out32(popenhw_driver.config_base_addr, config_data);
```
```python
# Python Code (system.py)
config_data_0 = (1 << 0) | ((input_zp & 0xFF) << 8) | (((i0 - 1) & 0xFFFF) << 16)
await self.axi_master_config.write(0x00, config_data_0.to_bytes(4, 'little'))
```

**Polling for Done (C vs Python):**
```c
// C Code (driver.c)
done = (eaiot_hal_In32((popenhw_driver.config_base_addr+4)) >> 16) & 0x1;
```
```python
# Python Code (system.py)
val = int.from_bytes(read_val.data, 'little')
done = (val >> 16) & 0x1
```