import numpy as np
import cocotb
from cocotb.triggers import Timer
from cocotbext.axi import AxiBus, AxiMaster


# Hardware Configuration for matching with verilog codes 
# --------------------------------------------------------------------------

class HwConfig:
    MAX_INPUT_SIZE = 32  # as known as I0
    MAX_PES = 32         # aka O0
    INPUT_D_W = 8
    WEIGHT_MEM_D_W = 8
    PE_D_W = 32





# Hardware Driver
# --------------------------------------------------------------------------

class accel_driver():
    def __init__(self, dut, logic_duty, axi_duty, axi_master_config, axi_master_iwb, axi_master_ra):
        self.dut = dut
        self.logic_duty = logic_duty
        self.axi_duty = axi_duty
        self.axi_master_config = axi_master_config
        self.axi_master_iwb = axi_master_iwb
        self.axi_master_ra = axi_master_ra

    async def bias_setup(self, bias_tile, o0):
        pass
    
    async def hw_setup(self, input_tile, weight_tile, input_zp, i0, o0):
        pass

    async def recv_output(self, o0):
        pass





# Layer Scheduler
# --------------------------------------------------------------------------

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

    async def forward(self, input_tensor):
        pass