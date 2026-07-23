# NN Accelerator Cocotb Verification

## Part 1: Neural Network & Hardware Mapping Concepts

### 1.1 Overview
This document explains the complete architecture of our custom Neural Network (NN) accelerator and the Cocotb-based verification environment. Deep learning models are typically trained using high-precision floating-point numbers (FP32). However, running these models on custom hardware is extremely expensive in terms of area and power. 

To solve this, we use **Quantization** (converting floats to 8-bit integers) and **Tiling** (breaking large matrix multiplications into smaller hardware-friendly chunks).

### 1.2 Neural Network Layers
The accelerator is designed to support two fundamental neural network layers:
*   **Linear Layer (Fully Connected / MLP):** Takes a 1D vector of inputs (e.g., a flattened 28x28 image = 784 pixels), multiplies each input by a corresponding weight, and sums them up to produce an output. This is a standard matrix-vector multiplication.
*   **Conv2d Layer (Convolutional):** Instead of multiplying the whole image at once, it slides a small 2D window (e.g., 3x3 pixels) across the image. At each step, it multiplies the 9 pixels inside the window by 9 weights and sums them to produce a single output pixel. This preserves spatial relationships in images.

**Conv2d Parameters:**
The behavior of the sliding window is controlled by four key parameters:
*   **`stride`:** Determines how many pixels the window jumps at each step. `stride=1` means pixel-by-pixel movement. `stride=2` halves the output image size.
*   **`padding`:** When the window is at the edge of the image, part of it falls outside. `padding=1` adds a border of zeros around the image so the window can operate fully on edge pixels.
*   **`dilation`:** Spreads out the pixels *inside* the kernel. `dilation=2` means a 3x3 window covers a 5x5 area by skipping every other pixel. This increases the "receptive field" without adding more weights.
*   **`groups`:** Splits the input channels and output filters into independent groups. `groups=2` means the first half of the filters only look at the first half of the input channels. This reduces computation. If `groups=1`, every output filter looks at all input channels.

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

Notice the second term: $\beta \times S_w \times \sum (q_w)$. Because the hardware does not know about $\beta$ (the input shift), this term is not computed by the hardware. It must be calculated in Python as the `Offset`. In Linear layers, this is simply `offset = layer.qact.beta * scale * weight_sum`.

**Step 4: Quantizing the Bias for Hardware (Crucial Implementation Detail)**
Instead of adding the float bias ($b_{float}$) in Python at the end, we offload this to the hardware. The hardware accepts a 32-bit integer bias ($b_{int32}$) and adds it inside the accumulator:
$$ \text{Hardware Int32 Output} = \sum (q_x \times q_w) + b_{int32} $$

If we substitute this back into our Float Output equation:
$$ \text{Float Output} = \alpha \times \left( \sum (q_x \times q_w) + b_{int32} \right) + \text{Offset} $$
$$ \text{Float Output} = \alpha \times \sum (q_x \times q_w) + \alpha \times b_{int32} + \text{Offset} $$

For this to equal the original equation ($\alpha \times \sum (q_x \times q_w) + \text{Offset} + b_{float}$), the bias we send to the hardware must be quantized first:
$$ b_{int32} = \text{round}\left( \frac{b_{float}}{\alpha} \right) $$
In Python, this is implemented as: `bias_int = (layer.bias / alpha.squeeze()).round().to(torch.int32)`. This `bias_int` is sent to the hardware *before* computation. The original float bias is no longer added in Python.

**Step 5: The Conv2d Offset Problem & The All-Ones Trick**
In a Linear layer, $\sum(q_w)$ (the sum of weights) is a single constant because all weights are always used. 
However, in Conv2d, when the window is at the edges of the image, the `padding` region is effectively zero, meaning some weights are multiplied by zero and do not contribute to the sum. Therefore, the active $\sum(q_w)$ varies for every output pixel!

How do we calculate the sum of active weights for every single output pixel efficiently?
We use a mathematical trick: we create a dummy input image filled entirely with `1.0` and perform a standard convolution with the weights.
$$ \text{Dummy Output} = \sum \left( 1.0 \times q_w \right) = \sum_{\text{active}} (q_w) $$
Because padding is zero (not one), this dummy convolution perfectly outputs the exact sum of active weights for each spatial location. We then multiply this by $\beta \times S_w$ to get a spatial `Offset` map:
```python
valid_input = torch.ones((1, Cin, H, W), dtype=torch.float32)
offset = F.conv2d(valid_input, q_weight_i8.float(), None, stride, padding, dilation, groups)
offset = offset * (layer.qact.beta * scale).view(1, -1, 1, 1)
```

**Step 6: The Final Dequantization Formula**
Finally, what remains in Python is just multiplying the hardware output by $\alpha$ and adding the pre-calculated `Offset` (which is a vector for Linear, or a matrix for Conv2d):
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

In the physical board, an ARM processor runs C code (`LLRT/driver.c`) to communicate with the FPGA. In our simulation, we replace the ARM processor with a Python script. The `accelerator_driver` class in `src/system.py` is the direct Python equivalent of the C driver.

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

### 3.3 Driver Methods & The Critical Scheduling Fix

There was a critical scheduling bug in the initial driver implementation where the `start` signal was asserted *before* the inputs and weights were fully written to BRAM. Because the hardware FSM transitions from `S_IDLE` to `S_CALCULATE` immediately upon receiving `start=1`, triggering it early causes the hardware to process garbage data.

**The Rule:** Data must be written to BRAM, and `output_num` must be configured, *before* the `start` bit is set.

#### A. `bias_setup(bias_tile, o0)`
Writes 32-bit quantized bias values ($b_{int32}$) to the Register Array BRAM. As explained in section 1.4, the floating-point bias is first divided by $\alpha$ and rounded to the nearest integer in Python. The hardware expects exactly `MAX_PES` registers, so we pad the rest of the NumPy array with zeros and write to offset `0x00`.

#### B. `hw_setup(input_tile, weight_tile, input_zp, i0, o0)`
Sends data, configures the engine, starts it, and waits for completion. **The order of operations here is strictly enforced:**

1.  **Write Inputs:** Pack `i0` inputs into a 32-element `uint8` array. Write to `axi_master_iwb` offset `0x00`.
2.  **Write Weights:** For each PE `k`, pack 32 weights. Write to offset `(k + 1) * 32`.
3.  **Configure Output Num:** Write `(o0 - 1)` to `axi_master_config` offset `0x04`.
4.  **Configure Start/Input (Trigger):** Pack `start(1)`, `input_zp`, `input_num` into a 32-bit word and write to offset `0x00`. This triggers the FSM, so it must be the absolute last step.
5.  **Poll for Done:** Read offset `0x04`. The `done` flag is in `byte_ram[6]`. Since reading `0x04` fetches bytes 4, 5, 6, and 7, byte 6 is at index `2` in the received array. The Pythonic code `done = bool(read_val.data[2])` checks this flag without complex bitwise shifting.
6.  **Clear Start:** Write `0` to offset `0x00` to return the FSM to `S_IDLE` for the next tile.

#### C. `recv_output(o0)`
Reads 128 bytes (32 x 32-bit words) from `axi_master_ra` offset `0x00` and converts them back into an `int32` NumPy array. This happens after the `done` flag is polled.

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

---

## Part 4: CNN & Conv2d Implementation Deep Dive (Theory & Code)

### 4.1 The Theory: Conv2d Math and Zero-Point Padding
In a standard floating-point Conv2d, the sliding window multiplies input pixels by weights. When the window is at the edge of the image, `padding` is used. In floating-point, padding is simply `0.0`.

However, in our quantized hardware, the input is `uint8` and has a Zero Point ($ZP$). The hardware computes: `(Input - ZP) * Weight`. 
If we pad the image with `0` (integer zero), the hardware will compute `(0 - ZP) * Weight = -ZP * Weight`, which introduces a massive artificial error! 

**The Solution:** The image must be padded with the `input_zp` value itself. 
Mathematically: `(input_zp - input_zp) * Weight = 0 * Weight = 0`.
This perfectly mimics the floating-point zero-padding behavior.

### 4.2 The Theory: The "All-Ones" Offset Trick
As explained in Part 1, the hardware doesn't know about $\beta$ (the input shift). The offset formula is:
$$ \text{Offset} = \beta \times S_w \times \sum (q_w) $$

In Linear layers, $\sum(q_w)$ is constant. But in Conv2d, at the edges of the image, some weights are multiplied by the padded zeros, meaning they don't contribute to the output. The active sum of weights changes for every single output pixel!

To compute this efficiently without tracking which weights are active per pixel, we use a dummy convolution:
1. Create an input tensor of ones with the same spatial size as the original input.
2. Perform standard Conv2d: `F.conv2d(ones, weights)`. 
3. Because the padding is zero (not one), the output of this dummy convolution is exactly the sum of the active weights at every spatial location!
4. Multiply this by $\beta \times S_w$ to get the final spatial `Offset` map.

---

### 4.3 The Implementation: Mapping Theory to `_process_conv2d` Code
Let's look at your exact code in `system.py` and see how the hardware limits, padding, and tiling are handled.

#### A. Loop Structure and Spatial Iteration
The hardware can only compute 32 outputs (`MAX_PES`) from 32 inputs (`MAX_INPUT_SIZE`) at a time. In Conv2d, the "inputs" to the MAC operation are the channels inside the sliding window.

Your code iterates spatially (`oh`, `ow`), then tiles the output channels (`ob_start`), then iterates over the kernel (`kh`, `kw`), and finally tiles the input channels (`ib_start`).

```python
# Spatial iteration: moving the sliding window across the image
for oh in range(Hout):
    for ow in range(Wout):
        
        # Output Channel Tiling (Max 32 PEs at a time)
        for ob_start in range(0, out_channels, HWConfig.MAX_PES):
            ob_size = min(out_channels - ob_start, HWConfig.MAX_PES)
            
            # Load the quantized bias for this specific set of output channels
            bias_tile = bias_int[ob_start:ob_start+ob_size].cpu().numpy()
            await self.driver.bias_setup(bias_tile, ob_size)
            
            # Kernel iteration: sliding window is made of Kh x Kw x Cin pixels
            for kh in range(Kh):
                ih = oh * stride[0] + kh * dilation[0] - padding[0]
                for kw in range(Kw):
                    iw = ow * stride[1] + kw * dilation[1] - padding[1]
```

#### B. Handling Zero-Point Padding in Hardware
Inside the kernel loop, you must check if the current window pixel falls outside the original image boundaries. If it does, you don't fetch from memory; you send `input_zp` directly to the hardware.

```python
                    if ih < 0 or ih >= H or iw < 0 or iw >= W:
                        # PADDING REGION: 
                        # We feed input_zp to the hardware.
                        # Hardware computes: (input_zp - input_zp) * weight = 0.
                        for ib_start in range(0, input_channel_group, HWConfig.MAX_INPUT_SIZE):
                            ib_size = min(input_channel_group - ib_start, HWConfig.MAX_INPUT_SIZE)
                            
                            input_tile = np.full(ib_size, input_zp, dtype=np.uint8)
                            weight_tile = q_weight_i8[ob_start:ob_start+ob_size, ib_start:ib_start+ib_size, kh, kw].cpu().numpy()
                            
                            await self.driver.hw_setup(input_tile, weight_tile, input_zp, ib_size, ob_size)
```

#### C. Handling Groups and Input Channel Tiling
If `groups > 1`, not all output channels look at all input channels. Output channels in group `g` only look at input channels belonging to group `g`. Your code correctly calculates the starting input channel based on the current output block.

```python
                    else:
                        # VALID IMAGE REGION:
                        # Fetch actual quantized data from memory.
                        for ib_start in range(0, input_channel_group, HWConfig.MAX_INPUT_SIZE):
                            ib_size = min(input_channel_group - ib_start, HWConfig.MAX_INPUT_SIZE)
                            
                            # Group calculation: map output channels to their respective input channels
                            g = ob_start // (out_channels // groups)
                            in_channel_start = g * input_channel_group + ib_start
                            
                            # Extract the 1D vector of inputs for this specific pixel and channel group
                            input_tile = q_input_u8[n, in_channel_start:in_channel_start+ib_size, ih, iw].view(-1).cpu().numpy()
                            weight_tile = q_weight_i8[ob_start:ob_start+ob_size, ib_start:ib_start+ib_size, kh, kw].cpu().numpy()
                            
                            await self.driver.hw_setup(input_tile, weight_tile, input_zp, ib_size, ob_size)
```

#### D. Accumulation and The All-Ones Offset Code
After all kernel elements and input channels for an output pixel are processed, the hardware's internal accumulator holds the raw integer result. We read it, and in Python, we apply the `alpha` scale and the spatial `Offset` map (calculated via the All-Ones trick).

```python
            # Read the 32-bit integer accumulator from hardware
            out_tile = await self.driver.read_output(ob_size)
            acc_out[n, ob_start:ob_start+ob_size, oh, ow] = torch.from_numpy(out_tile)

# --- AFTER ALL LOOPS FINISH ---

# 1. Calculate the spatial offset map using the All-Ones trick
valid_input = torch.ones((1, input_channels, H, W), dtype=torch.float32)
# This dummy convolution outputs the exact sum of active weights at each pixel
offset = F.conv2d(valid_input, q_weight_i8.float(), None, stride, padding, dilation, groups)
# Multiply by (beta * scale) to complete the offset math
offset = offset * (layer.qact.beta * scale).view(1, -1, 1, 1)

# 2. Final Dequantization: apply alpha and offset
self.output = acc_out.float() * alpha + offset
```
