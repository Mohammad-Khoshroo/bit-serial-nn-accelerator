import numpy as np
from math import *
import torch
import torch.nn.init as init
import cocotb
import cocotb.triggers
from cocotb.triggers import Timer
from cocotb.binary import BinaryValue
from cocotb.triggers import FallingEdge, Timer, RisingEdge
from cocotb.clock import Clock

from cocotbext.axi import AxiBus, AxiMaster
from cocotb.utils import get_sim_time


@cocotb.test()
async def layer_scheduler_tb(dut):

    axi_duty = 10
    logic_duty = 40
    
    
    await cocotb.start(Clock(dut.s00_axi_aclk, axi_duty, units="ps").start())
    await cocotb.start(Clock(dut.s01_axi_aclk, axi_duty, units="ps").start())
    await cocotb.start(Clock(dut.s02_axi_aclk, axi_duty, units="ps").start())

    await cocotb.start(Clock(dut.logic_clk, logic_duty, units="ps").start())

    dut.s00_axi_aresetn.value = 0
    dut.s01_axi_aresetn.value = 0
    dut.s02_axi_aresetn.value = 0
    dut.logic_rstn = 0
    await Timer(100)
    dut.s00_axi_aresetn.value = 1
    dut.s01_axi_aresetn.value = 1
    dut.s02_axi_aresetn.value = 1
    dut.logic_rstn = 1
    await Timer(200)

    ### Example layer and input generation
    ### your code should support QuantConv2d, and QuantLinear
    in_channels = 3
    out_channels = 8
    kernel_size = (3, 3)
    stride = (1, 1)
    groups = 1
    bias = False
    padding = (0, 0)
    input_dim = (1, in_channels, 28, 28)
    layer = QuantConv2d(in_channels,out_channels, kernel_size, stride, padding, groups = groups, bias=bias)
    init.normal_(layer.weight, mean=0.0, std=0.01)
    test_input = torch.randn(*input_dim)
    golden_output = layer(test_input) # create golden results
    ###
    start_time = get_sim_time(units="ns")



    AH = layer_scheduler(layer, dut, logic_duty, axi_duty)
    task = await cocotb.start(AH.forward(test_input))
    await cocotb.triggers.Join(task)

    assert AH.output == golden_output # verify the layer output
    
    end_time = get_sim_time(units="ns")
    
    print(f'hardware layer takes: {end_time - start_time}')

    

class layer_scheduler():
    def __init__(self, layer, dut, logic_duty, axi_duty):
        self.layer = layer
        self.dut = dut
        self.logic_duty = logic_duty
        self.axi_duty = axi_duty

        self.axi_master_config = AxiMaster(AxiBus.from_prefix(dut, "s00_axi"), dut.s00_axi_aclk, dut.s00_axi_aresetn, reset_active_level=False)
        self.axi_master_iwb = AxiMaster(AxiBus.from_prefix(dut, "s01_axi"), dut.s01_axi_aclk, dut.s01_axi_aresetn, reset_active_level=False)
        self.axi_master_ra = AxiMaster(AxiBus.from_prefix(dut, "s02_axi"), dut.s02_axi_aclk, dut.s02_axi_aresetn, reset_active_level=False)
        self.driver = accel_driver(dut, logic_duty, axi_duty, self.axi_master_config, self.axi_master_iwb, self.axi_master_ra)

    def forward(self, input):
        pass

class accel_driver():
    def __init__(self, dut, logic_duty, axi_duty, axi_master_config, axi_master_iwb, axi_master_ra):
        self.dut = dut
        self.logic_duty = logic_duty
        self.axi_duty = axi_duty
        self.axi_master_config = axi_master_config
        self.axi_master_iwb = axi_master_iwb
        self.axi_master_ra = axi_master_ra

    async def hw_setup(self):
        pass

    async def bias_setup(self):
        pass

    async def recv_output(self):
        pass