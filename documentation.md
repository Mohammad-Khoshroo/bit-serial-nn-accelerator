# NN Accelerator Cocotb Verification

## Part 1: Neural Network & Hardware Mapping Concepts

### 1.1 Overview
This document explains the complete architecture of our custom Neural Network (NN) accelerator and the Cocotb-based verification environment. Deep learning models are typically trained using high-precision floating-point numbers (FP32). However, running these models on custom hardware is extremely expensive in terms of area and power. 

To solve this, we use **Quantization** (converting floats to 8-bit integers) and **Tiling** (breaking large matrix multiplications into smaller hardware-friendly chunks).

### 1.2 Neural Network Layers
The accelerator is designed to support two fundamental neural network layers:
*   **Linear Layer (Fully Connected / MLP):** Takes a 1D vector of inputs (e.g., a flattened 28x28 image = 784 pixels), multiplies each input by a corresponding weight, and sums them up to produce an output. This is a standard matrix-vector multiplication.
*   **Conv2d Layer (Convolutional):** Instead of multiplying the whole image at once, it slides a small 2D window (e.g., 3x3 pixels) across the image. At each step, it multiplies the 9 pixels inside the window by 9 weights and sums them to produce a single output pixel. This preserves spatial relationships in images.

### 1.3 Quantization (The Shift from Float to Int)
Computers and FPGAs process integer math much faster and with significantly less power than floating-point math. **Quantization** is the process of mapping continuous floating-point values to discrete 8-bit integers (`int8` or `uint8`).

The mathematical relationship between the floating-point value ($x_{float}$) and its quantized integer representation ($x_{int}$) is defined by a Scale ($S$) and a Zero Point ($ZP$):
$$ x_{float} \approx (x_{int} - ZP) \times S $$

*   **Scale ($S$):** The step size between representable integer values. (e.g., 1 integer unit = 0.1 float units).
*   **Zero Point ($ZP$):** The integer value that corresponds to the real-world float value of `0.0`. This is crucial because `0` appears frequently in neural networks (e.g., after ReLU activation).

**Why does the hardware need $ZP$?**
Floating-point numbers can be negative (e.g., -0.5), but our hardware accelerator only accepts unsigned 8-bit integers (`uint8`, range 0 to 255) for inputs. By adding $ZP$ (e.g., $ZP=128$), negative float values are shifted into the positive integer range. The hardware then internally subtracts this $ZP$ to restore the original signed mathematical value.

**The Hardware's Perspective:**
Our hardware accelerator does *not* understand floating-point numbers, Scales, or complex math. It only understands 8-bit integers. Therefore, to compute the multiplication of an input and a weight, the hardware only needs the integer values and the Zero Point to perform:
$$ \text{Hardware MAC} = \sum (\text{Input}_{int} - \text{Input}_{ZP}) \times \text{Weight}_{int}$$
*(Note: Weights are symmetrically quantized, so their Zero Point is 0).*

### 1.4 The Golden Model, Bias, and Dequantization Math
To verify that our hardware computed the correct result, we compare it against a "Golden Model." In this project, the Golden Model is PyTorch running the exact same layer.

PyTorch computes the layer using integers behind the scenes, but to output a meaningful float number, it must "Dequantize" the hardware's 32-bit integer result back into a float. Let's break down the math step-by-step to understand how this works, where the Bias fits in, and how the `Offset` is calculated.

**Step 1: The Quantization Formula (LSQ+)**
In this project, inputs are quantized asymmetrically using LSQ+, where the float value is approximated by an integer ($q_x$), a scale ($S_x$), and a shift parameter $\beta$:
$$ x_{float} \approx (q_x \times S_x) + \beta $$
Weights are symmetrically quantized (Zero Point = 0):
$$ w_{float} \approx q_w \times S_w $$

**Step 2: The Float MAC Equation**
In a standard neural network layer, the float output is computed as:
$$ \text{Float Output} = \sum (x_{float} \times w_{float}) + b_{float} $$

Substituting the quantized values:
$$ \text{Float Output} = \sum \left( \left[ (q_x \times S_x) + \beta \right] \times \left[ q_w \times S_w \right] \right) + b_{float} $$

**Step 3: Expanding and Factoring out Scales**
If we expand the multiplication inside the summation:
$$ \text{Float Output} = \sum (q_x \times q_w \times S_x \times S_w) + \sum (\beta \times q_w \times S_w) + b_{float} $$

Since $S_x$, $S_w$, and $\beta$ are constants for the layer, we can factor them out:
$$ \text{Float Output} = \underbrace{(S_x \times S_w)}_{\alpha} \times \underbrace{\sum (q_x \times q_w)}_{\text{Hardware Int32 Output}} + \underbrace{\beta \times S_w \times \sum (q_w)}_{\text{Offset}} + b_{float} $$

Notice the first term: $\alpha \times \sum (q_x \times q_w)$. This is exactly what our hardware computes! The hardware multiplies the integers and sums them. 

Notice the second term: $\beta \times S_w \times \sum (q_w)$. Because the hardware does not know about $\beta$ (the input shift), this term is not computed by the hardware. It must be calculated in Python as the `Offset`. In code, this is `offset = layer.qact.beta * scale * weight_sum`.

**Step 4: Quantizing the Bias for Hardware**
Instead of adding the float bias ($b_{float}$) in Python at the end, we want the hardware to do it. The hardware accepts a 32-bit integer bias ($b_{int32}$) and adds it inside the accumulator:
$$ \text{Hardware Int32 Output} = \sum (q_x \times q_w) + b_{int32} $$

If we substitute this back into our Float Output equation:
$$ \text{Float Output} = \alpha \times \left( \sum (q_x \times q_w) + b_{int32} \right) + \text{Offset} $$
$$ \text{Float Output} = \alpha \times \sum (q_x \times q_w) + \alpha \times b_{int32} + \text{Offset} $$

For this to equal the original equation ($\alpha \times \sum (q_x \times q_w) + \text{Offset} + b_{float}$), the bias we send to the hardware must be:
$$ b_{int32} = \text{round}\left( \frac{b_{float}}{\alpha} \right) $$

**Step 5: The Final Dequantization Formula**
Finally, what remains in Python is just multiplying the hardware output by $\alpha$ and adding the pre-calculated `Offset`:
$$ \text{Float Output} = (\text{Hardware Int32 Output} \times \alpha) + \text{Offset} $$

### 1.5 Tiling and Scheduling (Hardware Limits)
Neural network layers can be massive. However, our hardware has strict physical constraints defined in `hw_config.vh`:
*   `MAX_INPUT_SIZE = 32`: The hardware can only accept 32 inputs at a time.
*   `MAX_PES = 32`: The hardware only has 32 Processing Elements, so it can only produce 32 outputs at a time.

We cannot send the entire layer to the hardware at once. Instead, we break the large matrix multiplication into smaller "Tiles" of size 32x32. The host sends a tile, the hardware computes a partial 32-bit sum, and the host accumulates these partial sums until the full layer is processed. This process is called **Scheduling**.

---

## Part 2: Hardware Architecture & AXI Protocol

### 2.1 The Magic of `cocotbext-axi`
In standard Verilog testbenches, you would have to manually toggle `awvalid`, wait for `awready`, then send `wdata`, etc. Because we use the `cocotbext-axi` library in Python, the `AxiMaster` class handles all 5 AXI channels (AW, W, B, AR, R) and handshakes automatically in the background. Your only job is to know which interface to target and what offset to use.

### 2.2 Base Addresses vs. Offsets (Physical vs. Cocotb)
A common source of confusion is where the absolute base addresses (like `0x40000000`) come from.

*   **On the Physical Board:** The Verilog code does not know its absolute base address. An **AXI Interconnect** (routing chip) sits between the ARM processor and the accelerator. When the ARM processor writes to `0x40000004`, the Interconnect routes the packet to `s00_axi` and passes only the offset (`0x04`) to the Verilog module.
*   **In Our Cocotb Simulation:** There is no ARM processor and no AXI Interconnect. We create three distinct `AxiMaster` objects in Python, each hardwired **directly** to a specific Verilog port. 

Because the connections are direct, **the base addresses are completely "Dummy" (unused) in Cocotb.** When you call `axi_master_config.write(0x04, data)`, the library puts `0x04` directly onto the Verilog wires. The Verilog module simply uses this offset to index into its local memory array.

### 2.3 Little-Endian Data Packing
The AXI4 protocol and ARM processors use **Little-Endian** byte ordering by default. The least significant byte (LSB) is stored at the lowest address. 
When the Python driver converts an integer to bytes using `to_bytes(4, 'little')`, it ensures that the data aligns perfectly with the Verilog logic, which splits the 32-bit AXI bus into 8-bit memories:
```verilog
byte_ram[0] <= S_AXI_WDATA[7:0];   // LSB goes to byte 0
byte_ram[1] <= S_AXI_WDATA[15:8];  // Next byte goes to byte 1
```

---

## Part 3: Cocotb Driver Architecture & Implementation

In the physical board, an ARM processor runs C code (`LLRT/driver.c`) to communicate with the FPGA. In our simulation, we replace the ARM processor with a Python script. The `accel_driver` class in `src/system.py` is the direct Python equivalent of the C driver.

### 3.1 Hardware Configuration Mirroring (`HwConfig`)
Verilog parameters (macros from `hw_config.vh`) are evaluated at compile-time. Since Cocotb runs at runtime, it cannot read Verilog macros directly. To keep the Python code synchronized with the hardware, a mirror configuration class is used:
```python
class HwConfig:
    MAX_INPUT_SIZE = 32  # Mirror of I0 in hw_config.vh
    MAX_PES = 32         # Mirror of O0 in hw_config.vh
```

### 3.2 AXI Memory Map (Verilog Proofs)
The driver interacts with three AXI4 Slave interfaces. The Verilog code maps specific offsets to internal logic:

| Interface | Python Object | Purpose | Verilog Mapping |
| :--- | :--- | :--- | :--- |
| **Config** | `axi_master_config` | Control & Status | `byte_ram[0][0]=start`, `byte_ram[6][0]=done` |
| **Input/Weight** | `axi_master_iwb` | 8-bit Data BRAMs | `byte_ram[0..31]=inputs`, `byte_ram[32..]=weights` |
| **Register Array**| `axi_master_ra` | 32-bit Accumulators | `byte_ram[0..127]=bias/output` |

### 3.3 Driver Methods

#### A. `bias_setup(bias_tile, o0)`
Writes 32-bit bias values to the Register Array BRAM. As explained in the math section (1.4), the floating-point bias is first divided by $\alpha$ and rounded to the nearest integer before being sent here. The hardware expects exactly `MAX_PES` registers, so we pad the rest of the NumPy array with zeros and write to offset `0x00`.

#### B. `hw_setup(input_tile, weight_tile, input_zp, i0, o0)`
Sends data, configures the engine, starts it, and waits for completion.
1.  **Write Inputs:** Pack `i0` inputs into a 32-element `uint8` array. Write to `axi_master_iwb` offset `0x00`.
2.  **Write Weights:** For each PE `k`, pack 32 weights. Write to offset `(k + 1) * 32`.
3.  **Configure Output Num:** Write `(o0 - 1)` to `axi_master_config` offset `0x04`.
4.  **Configure Start/Input:** Pack `start(1)`, `input_zp`, `input_num` into a 32-bit word and write to offset `0x00`.
5.  **Poll for Done:** Read offset `0x04`. The `done` flag is in `byte_ram[6]`. Since reading `0x04` fetches bytes 4, 5, 6, and 7, byte 6 is at index `2` in the received array. The Pythonic code `done = bool(read_val.data[2])` checks this flag without complex bitwise shifting.
6.  **Clear Start:** Write `0` to offset `0x00` to return the FSM to `S_IDLE`.

#### C. `recv_output(o0)`
Reads 128 bytes (32 x 32-bit words) from `axi_master_ra` offset `0x00` and converts them back into an `int32` NumPy array.

### 3.4 C-to-Python Translation Evidence
The Python implementation strictly follows the logic of `src/LLRT/driver/driver.c`.

**Register Configuration:**
```c
// C Code
config_data = ((input_zp & 0xFF) << 8) | (((i0 - 1) & 0xFFFF) << 16) | 1;
```
```python
# Python Code
config_data_0 = (1 << 0) | ((input_zp & 0xFF) << 8) | (((i0 - 1) & 0xFFFF) << 16)
await self.axi_master_config.write(0x00, config_data_0.to_bytes(4, 'little'))
```

**Polling for Done:**
```c
// C Code
done = (eaiot_hal_In32((popenhw_driver.config_base_addr+4)) >> 16) & 0x1;
```
```python
# Python Code
read_val = await self.axi_master_config.read(0x04, length=4)
done = bool(read_val.data[2]) # byte_ram[6] is at index 2 of the 4-byte read
```