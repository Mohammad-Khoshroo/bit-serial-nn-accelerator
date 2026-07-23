# Introduction

In many AI systems, hardware accelerators are only part of the overall system, and a large portion of the neural network execution logic is handled in software. In such cases, the software must be able to communicate with the hardware — sending data, initiating operations, and receiving results.

As a first step, you need to use the **Cocotb** and **cocotbext-axi** libraries to build a software driver layer so that the base accelerator can be called like an ordinary function from within Python programs.

In this project, you must also perform the mapping and scheduling of two layers, **Conv2d** and **Linear**, in software on the core, simulate them using the implemented driver on the core, and finally compare the final output with the output of the golden model.

[Note: The software driver is the part of the Python code responsible for sending data, sending weights, configuring control registers, starting operations, and receiving output from the hardware.]

[Note: Mapping means converting the computations of a neural network layer into a set of operations executable on the hardware. Scheduling means determining the order in which these operations are executed, data is sent, and outputs are received.]

[Note: The Golden Model is usually the reference software implementation — for example in PyTorch or NumPy — against which the hardware output is compared.]

In the second step of this assignment, you will become familiar with a base architecture of a neural network accelerator, and then, by applying architecture-level optimization techniques, upgrade it from **Bit-Parallel** processing to **Bit-Serial** processing.

Finally, by leveraging **Bit-level Sparsity**, you will eliminate ineffectual computations and improve system efficiency. You will also perform verification using the simulation environment from the previous section and compare the results.

[Note: Bit-level Sparsity means that in the binary representation of data, many bits are zero. In bit-serial computation, this zero-ness of bits can be exploited to skip certain operations.]

---

# Step One: System Simulation and Verification with Cocotb

## Introduction to Cocotb

**Cocotb**, short for **Coroutine-based Co-simulation Testbench**, is an open-source framework for writing testbenches in **Python**. Unlike traditional testbenches written in Verilog or VHDL, Cocotb gives full control of the simulation to the Python program.

The advantages of this approach include:

- Easy generation of test data
- Analysis of results using Python's capabilities
- The ability to model high-level systems

For more information, refer to:

https://www.cocotb.org

[Note: Cocotb allows you to write test behavior in Python instead of writing complex testbenches in Verilog/VHDL, and to use features such as NumPy, PyTorch, file reading, numerical analysis, and output comparison.]

---

## The cocotbext-axi Library

Writing **AXI** transactions manually is very time-consuming. For this reason, the **cocotbext-axi** library is used. This library provides a complete **AXI Master** for the program.

For more information and sample code, refer to:

https://github.com/alexforencich/cocotbext-axi

[Note: In this project, cocotbext-axi acts as the AXI transaction generator — that is, it can be used from within Python to write to and read from the AXI bus, simulating the behavior of the Host.]

---

## Interface Structure

The hardware module has three independent AXI interfaces.

### Configuration Interface

- Sending settings
- Starting the operation
- Reading the completion status

[Note: This interface is typically used for writing control registers such as layer size, number of PEs, addresses, the start signal, and reading the done signal.]

### Input & Weight Interface

- Sending inputs
- Sending layer weights

[Note: This interface is used to fill the hardware's internal memories, such as the input BRAM and weight BRAMs.]

### Result Interface

- Sending Bias
- Receiving the computed output

[Note: In this project, it appears that Bias is sent through the Result path, and the final output is also read from this same interface.]

---

## Expected Deliverables

Along with the project statement, the initial simulator code files will be provided to you. By the end of the project, you are expected to be able to:

- Design a Cocotb-based hardware driver.
- Manage communication across the three AXI interfaces.
- Quantize the input and weights of the input layer.
- Map and schedule the input layer.
- Send each portion of input to the hardware.
- Detect the completion of hardware execution.
- Receive the output and return it to the scheduler unit.
- **DeQuantize** the final output.
- Compare the simulated layer output with the golden model.

[Note: DeQuantize refers to converting the quantized output — e.g., an 8-bit or 32-bit integer — back to its corresponding real/floating-point value so it can be compared with the golden model's output.]

Note: For implementing the scheduler and driver components, you may refer to the algorithms implemented in the C code and follow a similar approach.

You can also access the project through this link:

https://github.com/EAIoTIR/EAIoT-BackEnd

---

# Step Two: Hardware Architecture of the Accelerator

## Introduction to the Current Hardware Platform — Bit-Parallel Architecture

The current platform is a simple processing core for neural network layer computations — such as **Fully Connected** layers — designed based on the **Output Stationary** dataflow.

In this architecture, each **PE** (processing element) is responsible for computing and accumulating the final value of one output. All communication with the host processor is performed via the **AXI4** protocol.

[Note: In the Output Stationary dataflow, the output value (or partial sum of the output) is kept fixed inside the PE, and the inputs and weights are applied to it until the final output value is built up.]

---

## Main Components of the Base Architecture

### Data Memories — Input/Weight BRAMs

This module consists of **BRAM** memories that are populated via the **AXI** bus. Weights are stored as separate blocks for each **PE**, while input data resides in a shared block. The number of these computational units can also be configured at the system level.

[Note: BRAM is on-chip memory (FPGA) or a block memory module in hardware design, used to store inputs, weights, and sometimes outputs.]

### Cluster Unit Datapath

In each clock cycle, an 8-bit input data value is read from memory and simultaneously **broadcast** to all processing units. The **MAC** (Multiply-and-Accumulate) operation inside each processing unit is performed by a multiplier and an adder.

The shared input data, in the same cycle, is multiplied by the 8-bit weight dedicated to that PE, and the result is added to the 32-bit **Accumulator** value.

[Note: The MAC operation means multiplying the input by the weight and adding the product to the previous value of the accumulator.]

### Cluster Unit Controller

This unit consists of a state machine that coordinates the system's components and issues the necessary control signals to the computational units and data memories.

[Note: The FSM (Finite State Machine) determines what stage the hardware is in at any given moment — e.g., loading input, executing computation, incrementing the address, finishing computation, and asserting done.]

---

# Introduction to Bit-Serial Computation

In hardware implementations of deep neural networks (**DNNs**), the way operands are represented and processed has a direct impact on chip area, power consumption, and execution time. In the current (parallel) architecture, all bits of an 8-bit operand enter the multiplier in a single clock cycle.

In bit-serial computation, instead of parallel processing, operands are processed bit by bit over several consecutive cycles. In neural networks, typically one operand — e.g., the weight — is kept fixed in **parallel**, while the other operand — e.g., the input — is shifted in **serially**.

In each cycle, only one bit of the input is examined:

- If the input bit is 1, the weight value — taking into account the input bit's positional value (i.e., the **shift** amount) — is shifted and added to the accumulator.
- If the input bit is 0, no addition takes place, and the process moves to the next input bit.

[Note: For example, if input bit number 3 equals 1, the weight must be shifted by 3 bits — meaning the weight value is multiplied by 2 raised to the power of 3.]

---

## Advantages of Bit-Serial Computation

Among the advantages of **Bit-Serial** computation are the following:

### 1. Reduced Area and Power

Replacing full multipliers — which require many logic gates — with **AND** gates, shift registers, and adders.

[Note: A full hardware multiplier is generally more costly than a combination of shifting and addition, especially when the goal is to reduce power or area.]

### 2. Exploiting Bit-Level Data Sparsity

While most neural network accelerators can eliminate unnecessary computations when an input value is entirely zero (i.e., **value-level sparsity**), serial computation also allows exploitation of zero bits within otherwise non-zero operands to further increase efficiency.

[Note: Value-level sparsity means the entire input value is zero. Bit-level sparsity means the input value is not necessarily zero, but some bits of its binary representation are zero.]

---

## Disadvantages of Bit-Serial Computation

On the other hand, this approach can have the following drawbacks:

### 1. Increased Latency

Multiplying two 8-bit numbers now requires 8 clock cycles instead of 1. To compensate for this and achieve **throughput** comparable to bit-parallel computation, bit-serial accelerators typically increase the number of computational units.

[Note: Latency is the time required to complete a single operation. Throughput is the number of operations or outputs produced per unit of time.]

### 2. Increased Controller Complexity

These accelerators generally require more complex state machines to manage tasks such as extracting input bits and synchronizing the computational units.

---

# Part 1: Basic Implementation of Serial Computation

In this step, you must redesign the **Cluster** architecture, the computational unit, and other required components so that the input is processed bit-serially while the weights are processed in parallel.

To do this, you need to design a new module that reads the 8-bit input from memory, stores it, and in each cycle sends one bit of it, along with the necessary control signals, to all **PE**s. This unit is called the **Input Serializer**.

[Note: The original text contained the phrase "dnput serializer," which most likely refers to "Input Serializer."]

Next, the previous parallel multipliers must be replaced with hardware suitable for bit-serial computation, consisting of an **AND** gate for multiplying a single input bit by the weight, an adder, and a shift operator.

Note that in this design, both the weight and the input values are signed.

[Note: The signedness of the input and weight matters because, in two's complement representation, the sign bit and shift operations must be handled correctly. A naive unsigned design will not produce correct results for signed values.]

Also, since multiplying an 8-bit data value now takes 8 clock cycles, the state machine in the **cluster_ctrl** module must be updated so that new data — i.e., the next input and its corresponding weights — is fetched from memory exactly after these 8 cycles are complete. The necessary control signals must also be issued to the computational units, the **Input Serializer** unit, and the memories.

---

## Deliverables for This Step

### 1. Circuit Schematics

Draw the precise datapath of the bit-serial computational unit, as well as the **Input Serializer** control unit responsible for broadcasting the input bit by bit.

[Note: The schematic should show how the 8-bit input is stored, how bits are selected one by one, how the shift value is generated, and how it is sent to the PEs.]

### 2. Controller Design

Draw the state machine (automaton) of the new controller. Note that the **FSM** must be modified so that after fetching an input from memory, it remains in an intermediate state for 8 cycles to complete the bit-serial operation, and only then generates the next address.

[Note: To implement this behavior, a 3-bit counter for counting 0 to 7 is typically required.]

### 3. Hardware Code

Write the required **Verilog** code, modifying previous modules as necessary.

### 4. Testing the Bit-Serial Computational Unit

Write a comprehensive **testbench** to verify the computational unit on its own, and show that for a given set of inputs and weights, the final accumulator values in the bit-serial architecture exactly match the output of the base parallel architecture.

Report the expected values and the corresponding waveforms.

[Note: In this test, it is advisable to test several positive, negative, zero, and boundary values such as 127 and -128, since signedness can lead to hidden bugs.]

### 5. Full System Test in Cocotb

Using the simulator developed in the previous step, verify the new bit-serial system.

Additionally, by applying the same layer as input to both the bit-serial and bit-parallel systems, compare their execution times. For a fair comparison, assume the number of computational units in the bit-serial accelerator is 8 times that of the base accelerator.

[Note: Since each 8-bit multiplication in bit-serial computation takes 8 cycles, the number of PEs in the bit-serial version is scaled up 8x for a fair throughput comparison.]

---

# Part 2: Optimization — Skipping Ineffectual Operations

Given the nature of data in neural networks — especially after applying functions such as **ReLU** — inputs often contain many zero values, or their binary representations contain many zero bits. Multiplying by zero is an **ineffectual computation** that simply consumes clock cycles and power without contributing anything.

The goal of this part is to convert the fixed number of clock cycles into a variable, **data-dependent** number of cycles. To achieve this, you must modify the system so that it consumes a clock cycle only for input bits whose value is 1, completely **skipping** ineffectual computations.

[Note: In the base bit-serial design, 8 cycles are always consumed per input, even if only one bit of it is 1. In the optimized version, the number of cycles equals the number of 1-bits in the input.]

---

## Design Requirements

### 1. Extracting Non-Zero Positions

Modify the input control unit designed in the previous step so that it processes only bits with a value of 1. To do this, you must use circuits such as a **Leading-One Detector (LOD)** or a **Priority Encoder** to convert the 8-bit input into a set of indices (i.e., powers of 2) corresponding to bits whose value is 1.

[Note: A Priority Encoder finds one of the 1-bits in each cycle and passes its position as the shift amount to the PE. That bit must then be removed from the input mask so that the next 1-bit can be found in the following cycle.]

### 2. Modifying the Datapath in the Computational Unit

The **PE** now receives, instead of a 0/1 bit value, the "positional value" or **shift amount** of a 1-bit from the controller. The PE must shift the weight by this amount and add it to the accumulator. In this way, ineffectual computations from multiplying by a zero bit are entirely skipped.

[Note: In this scheme, the PE no longer needs to do anything for a zero bit, since only the positions of 1-bits are sent to the PE.]

### 3. Variable Scheduling

In this case, the execution time is no longer fixed at 8 cycles; instead, it is exactly equal to the number of 1-bits — the **popcount** — in the input value. The controller must be able to detect the completion of processing for one input and immediately begin fetching the next.

[Note: Popcount is the number of 1-bits in the binary representation of a number. For example, the popcount of `00010110` is 3.]

---

## Deliverables for This Step

### 1. Extractor Circuit Schematic

Design a circuit that, in each cycle, finds the position of the most significant 1-bit (or least significant, depending on your design) in the input data. Circuits such as a **Priority Encoder** or **Leading-One Detector** can be used for this purpose.

Draw the overall block diagram of the system, including this circuit, the computational units, and the signals between them.

Again, note that both the input and the weight are signed, and this must be accounted for in the design.

Also note that the designed circuit must be able to extract the position of one non-zero bit per clock cycle. For example, if the input has 5 non-zero bits, each position is extracted in one cycle, and the computation is completed in a total of 5 cycles.

[Note: If using an LOD, you typically start from the most significant bit. If using a least-significant-bit priority encoder, you start from the LSB. Both approaches are acceptable, as long as the correct shift value is passed to the PE.]

[Note: For signed data, it must be clear how the bit representation is interpreted. If two's complement is used, the weight's sign bit is negative, and a naive implementation of adding the shifted weight may require correction for the sign bit.]

### 2. Modifying the Datapath in the PE

In this design, the **PE**, instead of receiving the bit itself (0 or 1), receives the "positional value" or **shift amount** corresponding to that 1-bit, so it can shift the weight by that amount and add it to the accumulator. Provide the schematic for these changes.

[Note: The PE's datapath in this case typically includes a weight register, a shifter, an adder, and an accumulator. The PE's main input is no longer a bit, but a shift amount.]

### 3. Variable-Timing Controller Design

Update the controller's state machine (automaton). In this design, the execution time for one 8-bit input is no longer fixed at 8 cycles; rather, it equals the number of 1-bits in that input. The controller must be able to detect the completion of processing for one input and immediately load the next input word.

[Note: The controller can maintain a mask of remaining bits. Each time a 1-bit is processed, that bit is cleared from the mask. When the mask reaches zero, processing of that input is complete.]

### 4. Testing the Bit-Serial Computational Unit

Write a testbench similar to the previous step to verify the computational unit on its own, and show that for a given set of inputs and weights, the final accumulator values in the bit-serial architecture exactly match the output of the base parallel architecture.

Report the expected values and the corresponding waveforms.

[Note: It is advisable in this test to also compare the number of cycles consumed against the popcount of the input, in addition to checking the final value.]

### 5. Full System Test in Cocotb

Using the simulator from Step One, and as in the previous part, verify the new bit-serial system. By applying the same layer used in the previous part as input to the new bit-serial system, compare its execution time against the two previous configurations.

[Note: Three configurations can be compared: the base bit-parallel architecture, the bit-serial architecture with a fixed 8 cycles, and the optimized bit-serial architecture with data-dependent timing.]