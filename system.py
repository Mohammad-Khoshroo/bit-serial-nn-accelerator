import numpy as np
import cocotb
from cocotb.triggers import Timer
from cocotbext.axi import AxiBus, AxiMaster


# Hardware Configuration for matching with verilog codes 
# --------------------------------------------------------------------------

class HWConfig:
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
        """
        write bias values to the Register Array BRAM (s02_axi)
        The hardware expects exactly MAX_PES registers
        
        :param bias_tile: NUMPY array of int
        :param o0: num of actual output for tile
        """
        bias_data = np.zeros(HWConfig.MAX_PES, dtype=np.int32)
        bias_data[:o0] = bias_tile
        await self.axi_master_ra.write(0x0000, bias_data.tobytes())
    

    
    async def hw_setup(self, input_tile, weight_tile, input_zp, i0, o0):
        """
        config control regs
        send inputs and weights
        start the accelerator
        and polls for completion
        
        :param input_tile: NUMPY array of unsigned int
        :param weight_tile: NUMPY shape (o0, i0) array of signed int
        :param input_zp: Input zero point
        :param i0: num of inputs tile
        :param o0: num of outputs tile
        """

        # write start(1), input_zp, input_num, output_num
        config_data_0 = (1 << 0) | ((input_zp & 0xFF) << 8) | (((i0 - 1) & 0xFFFF) << 16)
        await self.axi_master_config.write(0x00, config_data_0.to_bytes(4, 'little'))        
        config_data_1 = (o0 - 1) & 0xFFFF
        await self.axi_master_config.write(0x04, config_data_1.to_bytes(4, 'little'))

        # write input to block 0
        inp_data = np.zeros(HWConfig.MAX_INPUT_SIZE, dtype=np.uint8)
        inp_data[:i0] = input_tile
        await self.axi_master_iwb.write(0x0000, inp_data.tobytes())
        # write weghts to remain blocks
        w_data = np.zeros((HWConfig.MAX_PES, HWConfig.MAX_INPUT_SIZE), dtype=np.int8)
        w_data[:o0, :i0] = weight_tile
        for k in range(o0):
            addr = (k + 1) * HWConfig.MAX_INPUT_SIZE
            await self.axi_master_iwb.write(addr, w_data[k].tobytes())


        # wait for done
        # done issue in byte_ram[6][0]
        done = 0
        while not done:
            read_val = await self.axi_master_config.read(0x04, length=4)
            done = bool(read_val.data[2])
            await Timer(10, units='ns') # pyright: ignore[reportArgumentType]
        
        # issue start(0) as acknowledge
        await self.axi_master_config.write(0x00, (0).to_bytes(4, 'little'))



    async def read_output(self, o0):
        """
        Read computed MAC result from the Register Array BRAM (s02_axi)
        
        :param o0: Number of outputs to read
        """
        read_len = HWConfig.MAX_PES * 4  # each output: 4 byte
        read_val = await self.axi_master_ra.read(0x0000, length=read_len)
        out_data = np.frombuffer(read_val.data, dtype=np.int32)
        return out_data[:o0]
    
    


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