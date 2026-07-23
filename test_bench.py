import sys
import os
import numpy as np
import torch
import torch.nn.init as init
import cocotb
from cocotb.triggers import Timer
from cocotb.clock import Clock
from cocotb.utils import get_sim_time
from cocotb.utils import get_sim_time
import logging

sys.path.append(os.path.abspath(os.path.join(os.path.dirname(__file__), 'src')))

# logging.getLogger("cocotb.cluster_wrapper_bit_serial").setLevel(logging.WARNING)
# logging.getLogger("cocotb.cluster_wrapper_bit_sparsity").setLevel(logging.WARNING)
logging.getLogger("cocotb.cluster_wrapper").setLevel(logging.WARNING)

logging.getLogger("cocotbext.axi").setLevel(logging.WARNING)

from lsqplus import QuantConv2d, QuantLinear
from system import layer_tiling, HWConfig

async def setup_dut(dut):
    """Helper function to initialize clocks and reset the hardware."""
    axi_duty = 10
    logic_duty = 40
    
    await cocotb.start(Clock(dut.s00_axi_aclk, axi_duty, units="ps").start()) # pyright: ignore[reportArgumentType]
    await cocotb.start(Clock(dut.s01_axi_aclk, axi_duty, units="ps").start()) # pyright: ignore[reportArgumentType]
    await cocotb.start(Clock(dut.s02_axi_aclk, axi_duty, units="ps").start()) # pyright: ignore[reportArgumentType]
    await cocotb.start(Clock(dut.logic_clk,  logic_duty, units="ps").start()) # pyright: ignore[reportArgumentType]

    dut.s00_axi_aresetn.value = 0
    dut.s01_axi_aresetn.value = 0
    dut.s02_axi_aresetn.value = 0
    dut.logic_rstn.value = 0
    await Timer(100, units="ns") # pyright: ignore[reportArgumentType]
    
    dut.s00_axi_aresetn.value = 1
    dut.s01_axi_aresetn.value = 1
    dut.s02_axi_aresetn.value = 1
    dut.logic_rstn.value = 1
    await Timer(200, units="ns") # pyright: ignore[reportArgumentType]


@cocotb.test()
async def test_conv2d_layer(dut):
    """Test QuantConv2d layer with padding and bias against Golden Model."""
    await setup_dut(dut)

    in_channels = 3
    out_channels = 8
    kernel_size = (3, 3)
    stride = (1, 1)
    groups = 1
    bias = True
    padding = (1, 1)
    input_dim = (1, in_channels, 8, 8)
    
    layer = QuantConv2d(in_channels, out_channels, kernel_size, stride, padding,  # pyright: ignore[reportArgumentType]
                        groups=groups, bias=bias, a_bit=8, w_bit=8)
    init.normal_(layer.weight, mean=0.0, std=0.01)
    
    test_input = torch.randn(*input_dim)
    
    layer.train()
    _ = layer(test_input)
        
    layer.eval()
    golden_output = layer(test_input) 

    start_time = get_sim_time(units="ns") # pyright: ignore[reportArgumentType]
    
    AH = layer_tiling(layer, dut, logic_duty=40, axi_duty=10)
    await AH.forward(test_input)
    
    end_time = get_sim_time(units="ns") # pyright: ignore[reportArgumentType]
    
    hw_output = AH.output
    
    print("\n--- Conv2d Golden Output Sample ---")
    print(golden_output.flatten()[:5])
    print("--- Conv2d Hardware Output Sample ---")
    print(hw_output.flatten()[:5])
    
    assert torch.allclose(hw_output, golden_output, atol=1e-3, rtol=1e-3), \
        "Conv2d Hardware output does not match golden output!"
    
    print(f'\n[SUCCESS] Conv2d test passed! Execution time: {end_time - start_time} ns')


@cocotb.test()
async def test_linear_layer(dut):
    """Test QuantLinear (MLP) layer with bias against Golden Model."""
    await setup_dut(dut)

    in_features = 64
    out_features = 32
    input_dim = (1, in_features)
    
    layer = QuantLinear(in_features, out_features, bias=True, a_bit=8, w_bit=8)
    init.normal_(layer.weight, mean=0.0, std=0.01)
    
    test_input = torch.randn(*input_dim)
    
    layer.train()
    _ = layer(test_input)
        
    layer.eval()
    golden_output = layer(test_input)

    start_time = get_sim_time(units="ns") # pyright: ignore[reportArgumentType]
    
    AH = layer_tiling(layer, dut, logic_duty=40, axi_duty=10)
    await AH.forward(test_input)
    
    end_time = get_sim_time(units="ns") # pyright: ignore[reportArgumentType]
    
    hw_output = AH.output
    
    print("\n--- Linear Golden Output Sample ---")
    print(golden_output.flatten()[:5])
    print("--- Linear Hardware Output Sample ---")
    print(hw_output.flatten()[:5])
    
    assert torch.allclose(hw_output, golden_output, atol=1e-3, rtol=1e-3), \
        "Linear Hardware output does not match golden output!"
        
    print(f'\n[SUCCESS] Linear test passed! Execution time: {end_time - start_time} ns')
