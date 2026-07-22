# LLRT (Low-Level Runtime) Architecture

## 1. Overview
The `LLRT` (Low-Level Runtime) directory contains the C reference implementation of the software layer that sits between the neural network model and the hardware accelerator. Its primary responsibilities are:
1.  **Tiling/Scheduling:** Breaking down large layers (Conv2d, Gemm) into smaller chunks that fit the hardware limits (`I0` and `O0`).
2.  **Memory Management:** Copying weights, inputs, and biases into the hardware's AXI-mapped BRAMs.
3.  **Hardware Control:** Configuring registers, starting the engine, polling for completion, and reading back results.
4.  **Reference Golden Model:** Providing pure software implementations of quantized layers to verify hardware correctness.

*Note: For this Cocotb project, you do not compile or run this C code. You must read it and translate its exact logic (especially in `driver.c` and `layer/*.c`) into Python.*

## 2. Directory Structure
```text
src/LLRT/
├── driver/
│   ├── driver.c          # Low-level AXI read/write functions (Hardware Driver)
│   └── driver.h
├── layer/
│   ├── Padding.c         # Input zero-point padding logic
│   ├── Padding.h
│   ├── QConv1d.c         # 1D Convolution scheduling/tiling
│   ├── QConv1d.h
│   ├── QConv2d.c         # 2D Convolution scheduling/tiling
│   ├── QConv2d.h
│   ├── QGemm.c           # Matrix Multiplication scheduling/tiling
│   └── QGemm.h
├── tests/
│   ├── cases/            # Test cases that compare HW output to Golden Model
│   │   ├── conv1d.c
│   │   ├── conv2d.c
│   │   ├── gemm.c
│   │   └── test_cases.h
│   ├── ref/              # Pure software Golden Model implementations
│   │   ├── RQConv1d.c
│   │   ├── RQConv2d.c
│   │   └── RQGemm.c
│   └── utils/            # Test utilities (random gen, memory check)
│       ├── test_utils.c
│       └── test_utils.h
├── hardware_config.h     # Hardware limits (I0, O0)
└── utils.h               # Macros like LLRT_MIN
```

## 3. Hardware Configuration (`hardware_config.h`)
Defines the strict limits of the hardware accelerator.
```c
#define MAX_INPUT_SIZE 32 // as known as I0
#define MAX_NEURONS 32    // aka O0
```
The hardware can only process 32 inputs and 32 outputs at a single execution. The layer functions must respect these limits.

## 4. The Hardware Driver (`driver/driver.c`)
This is the most critical file for your Cocotb `accel_driver` class. It maps software arrays to hardware AXI addresses.

### Memory Layout & Base Addresses
The driver uses a struct `acc_driver_t` containing the AXI base addresses (which match the HW README):
*   `config_base_addr`: `0x40000000`
*   `iw_base_addr`: `0x40001000` (Input/Weight BRAM)
*   `o_base_addr`: `0x40002000` (Bias/Output Accumulators)

### Function: `hw_setup`
This function loads data into BRAMs and starts the engine.
```c
void hw_setup(uint8_t* input, int8_t* weight, int In_col, uint8_t input_zp, int i0, int o0) {
    // 1. Copy 'i0' inputs to Block 0 of iw_base_addr
    eaiot_hal_mem_copy(popenhw_driver.iw_base_addr, input, i0);

    // 2. Copy 'i0' weights for each PE (o0 times) to Blocks 1..32
    // Notice the address math: I0 + oi * I0. 
    // Since I0=32, PE 0 gets offset 32, PE 1 gets offset 64, etc.
    for (int oi = 0; oi < o0; oi++) {
        eaiot_hal_mem_copy(popenhw_driver.iw_base_addr + ((I0 + oi * I0)), weight + oi * In_col, i0);
    }

    // 3. Write output_num (o0-1) to config offset 0x04
    int config_data = ((o0 - 1) & 0xFFFF);
    eaiot_hal_Out32(popenhw_driver.config_base_addr + 4 , config_data);

    // 4. Write start(1), input_zp, and input_num (i0-1) to config offset 0x00
    // Bit 0: start=1, Bits 8-15: input_zp, Bits 16-31: i0-1
    config_data = ((input_zp & 0xFF) << 8) | (((i0 - 1) & 0xFFFF) << 16) | 1;
    eaiot_hal_Out32(popenhw_driver.config_base_addr, config_data);

    // 5. Poll config offset 0x04, bit 16 for 'done'
    int done = 0;
    while(!done) {
        done = (eaiot_hal_In32((popenhw_driver.config_base_addr+4)) >> 16) & 0x1;
    }

    // 6. Clear start bit by writing 0 to config offset 0x00
    eaiot_hal_Out32(popenhw_driver.config_base_addr, 0);
}
```
*Note for Python: The C code sends `i0` bytes. But AXI is 32-bit. In Cocotb, you will pack these 8-bit values into 32-bit words to send them over AXI.*

### Functions: `bias_setup` & `recv_output`
```c
// Copies 'o0' 32-bit integers to o_base_addr (0x40002000)
void bias_setup(int* bias, int o0) {
    eaiot_hal_mem_copy(popenhw_driver.o_base_addr, bias , o0 * sizeof(int));
}

// Reads 'o0' 32-bit integers from o_base_addr (0x40002000)
void recv_output(int* out, int o0) {
    eaiot_hal_mem_copy(out, popenhw_driver.o_base_addr, o0 * sizeof(int));
}
```

## 5. Layer Scheduling & Tiling (`layer/`)
Because the hardware only accepts `I0=32` inputs and `O0=32` outputs, the layer functions break the computation into nested loops.

### Example: `QGemm.c` (Matrix Multiplication)
```c
void QGemm(int* out, uint8_t* input, int8_t* weight, int* bias, ...) {
    for (int ir=0; ir < In_row; ir += 1) {
        for (int oc = 0; oc < Out_col; oc += O0) {         // Tile outputs by 32
            int o0 = LLRT_MIN(Out_col - oc, O0);
            
            bias_setup(bias + ir * Out_col + oc, o0);      // Load bias for this tile
            
            for (int ic = 0; ic < In_col; ic += I0) {      // Tile inputs by 32
                int i0 = LLRT_MIN(I0, In_col - ic);
                
                // Send tile to hardware
                hw_setup(input + ir * In_col + ic, 
                         weight + oc * In_col + ic, 
                         In_col, input_zp, i0, o0);
            }
            recv_output(out + ir * Out_col + oc, o0);      // Read output for this tile
        }
    }
}
```
*Note for Python: Your `layer_scheduler.forward()` method in Cocotb must replicate this exact loop structure for `QuantLinear` (Gemm) and `QuantConv2d`.*

### Padding (`Padding.c`)
Before convolution, the input is padded with the `input_zp` value (not zero) to maintain quantization correctness.
```c
for (int i = 0; i < Hp * Wp * Cin; i++) padded[i] = input_zp;
// Then copy original input into the center of the padded array
```

## 6. Reference Golden Model (`tests/ref/`)
These files contain the pure mathematical implementation of the quantized operations. They do NOT call any hardware functions. They compute the expected result using pure C integer math.

### Math Formula (found in `RQGemm.c`, `RQConv2d.c`, etc.)
```c
temp += (((int)input[...]) - (int)input_zp) * (int)weight[...];
```
This matches the hardware exactly: `(input - input_zp) * weight`. 
*Note for Python: PyTorch's `lsqplus.py` already handles this math. You will use PyTorch as your Golden Model, but knowing this formula helps debug mismatches.*

## 7. Test Cases (`tests/cases/`)
The test files (`gemm.c`, `conv2d.c`, etc.) show how the system is verified:
1.  Generate random `input` (uint8), `weight` (int8), and `bias` (int32).
2.  Call the Hardware function (e.g., `QGemm`), which writes to hardware and reads back `hw_out`.
3.  Call the Reference function (e.g., `RQGemm`), which computes `ref_out` in software.
4.  Compare them: `check_mem(hw_out, ref_out, size)`.

