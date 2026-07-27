import numpy as np
import torch
import torch.nn.functional as F
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

class accelerator_driver():


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

        # write start(1), input_zp, input_num, output_num
        config_data_1 = (o0 - 1) & 0xFFFF
        await self.axi_master_config.write(0x04, config_data_1.to_bytes(4, 'little'))
        config_data_0 = (1 << 0) | ((input_zp & 0xFF) << 8) | (((i0 - 1) & 0xFFFF) << 16)
        await self.axi_master_config.write(0x00, config_data_0.to_bytes(4, 'little'))        

        # wait for done
        # done issue in byte_ram[6][0]
        done = 0
        while not done:
            read_val = await self.axi_master_config.read(0x04, length=4)
            done = bool(read_val.data[2])
            await Timer(10, unit='ns') # pyright: ignore[reportArgumentType]
        
        # issue start(0) as acknowledge
        await self.axi_master_config.write(0x00, (0).to_bytes(4, 'little'))



    async def read_output(self, o0):
        """
        Read computed MAC result from the Register Array BRAM (s02_axi)
        
        :param o0: Number of outputs to read
        """
        read_len = HWConfig.MAX_PES * 4  # each output: 4 byte
        read_val = await self.axi_master_ra.read(0x0000, length=read_len)
        out_data = np.frombuffer(read_val.data, dtype=np.int32).copy()
        return out_data[:o0]
    
    


# Layer tiling
# --------------------------------------------------------------------------

class layer_tiling():
    def __init__(self, layer, dut, logic_duty, axi_duty):
        self.layer = layer
        self.dut = dut
        self.logic_duty = logic_duty
        self.axi_duty = axi_duty

        self.axi_master_config = AxiMaster(AxiBus.from_prefix(dut, "s00_axi"), dut.s00_axi_aclk, dut.s00_axi_aresetn, reset_active_level=False)
        self.axi_master_iwb = AxiMaster(AxiBus.from_prefix(dut, "s01_axi"), dut.s01_axi_aclk, dut.s01_axi_aresetn, reset_active_level=False)
        self.axi_master_ra = AxiMaster(AxiBus.from_prefix(dut, "s02_axi"), dut.s02_axi_aclk, dut.s02_axi_aresetn, reset_active_level=False)
        
        self.driver = accelerator_driver(dut, logic_duty, axi_duty, self.axi_master_config, self.axi_master_iwb, self.axi_master_ra)

    async def forward(self, input_tensor):
        """
           u8: uint-8bit
           i8: int-8bit
           q_: quantized
            
        """            
        layer = self.layer
        
        # quantization
        q_input  = layer.qunatized_input(input_tensor)
        q_weight = layer.qunatized_weight()
        
        # zero-point managing
        all_positive = layer.qact.all_positive
        if all_positive:
            input_zp = 0
            q_input_u8 = q_input.to(torch.uint8)
        else:
            # Shift signed q_input [-128, 127] to unsigned [0, 255]
            input_zp = 128
            q_input_u8 = (q_input + 128).to(torch.uint8)
            
        q_weight_i8 = q_weight.to(torch.int8)
        
        if 'linear' in layer.ltype:
            # MLP and Fully-Connected Networks 
            await self._process_linear(q_input_u8, q_weight_i8, input_zp, layer)
        elif 'conv2d' in layer.ltype:
            # CNN - convolution
            await self._process_conv2d(q_input_u8, q_weight_i8, input_zp, input_tensor, layer)
        
        return self.output
    
    async def _process_linear(self, q_input_u8, q_weight_i8, input_zp, layer):
            
            scale = layer._weight_scale()
            alpha = (scale * layer._activation_scale()).view(1, -1)
            
            # N: input number in each batch
            N, in_features = q_input_u8.shape
            out_features = q_weight_i8.shape[0]
            
            if layer.bias is not None:
                bias_int = (layer.bias / alpha.squeeze()).round().to(torch.int32)
            else:
                bias_int = torch.zeros(out_features, dtype=torch.int32)
            
            # acc: accelerator
            acc_out = torch.zeros((N, out_features), dtype=torch.int32)
            
            for n in range(N):
            
                # ob: tile output block
                # ib: tile input  block
                for ob_start in range(0, out_features, HWConfig.MAX_PES):
                    
                    # for handling 'the last output block' which can be less than MAX_PES
                    ob_size = min(out_features - ob_start, HWConfig.MAX_PES)
                    
                    bias_tile = bias_int[ob_start:ob_start+ob_size].cpu().numpy()
                    await self.driver.bias_setup(bias_tile, ob_size)
                    
                    for ib_start in range(0, in_features, HWConfig.MAX_INPUT_SIZE):
                        
                        # for handling 'the last input block' which can be less than MAX_INPUT_SIZE
                        ib_size = min(in_features - ib_start, HWConfig.MAX_INPUT_SIZE)
                        
                        input_tile = q_input_u8[n, ib_start:ib_start+ib_size].cpu().numpy()
                        weight_tile = q_weight_i8[ob_start:ob_start+ob_size, ib_start:ib_start+ib_size].cpu().numpy()
                        
                        await self.driver.hw_setup(input_tile, weight_tile, input_zp, ib_size, ob_size)
                        
                    out_tile = await self.driver.read_output(ob_size)
                    acc_out[n, ob_start:ob_start+ob_size] = torch.from_numpy(out_tile)
                    
            
            weight_sum = q_weight_i8.float().sum(dim=1)
            offset = layer.qact.beta * scale * weight_sum
            offset = offset.view(1, -1)
            
            self.output = acc_out.float() * alpha + offset
            

            
    async def _process_conv2d(self, q_input_u8, q_weight_i8, input_zp, input_tensor, layer):
        
        # N: input number in each batch
        # H: input hight 
        # W: input width
        # K: kernel
        # out_channels == filters number
        N, input_channels, H, W = input_tensor.shape
        out_channels, input_channel_group, Kh, Kw = q_weight_i8.shape
        
        stride = layer.stride
        padding = layer.padding
        dilation = layer.dilation
        groups = layer.groups
        
        Hout = (H + 2 * padding[0] - dilation[0] * (Kh - 1) - 1) // stride[0] + 1
        Wout = (W + 2 * padding[1] - dilation[1] * (Kw - 1) - 1) // stride[1] + 1
        
        scale = layer._weight_scale()
        alpha = (scale * layer._activation_scale()).view(1, -1, 1, 1)
        
        if layer.bias is not None:
            bias_int = (layer.bias / alpha.squeeze()).round().to(torch.int32)
        else:
            bias_int = torch.zeros(out_channels, dtype=torch.int32)
            
        # acc: accelerator 
        acc_out = torch.zeros((N, out_channels, Hout, Wout), dtype=torch.int32)
        
        for n in range(N):
            
            for oh in range(Hout):
                for ow in range(Wout):
                    
                    # ob: tile output block
                    # ib: tile input  block
                    for ob_start in range(0, out_channels, HWConfig.MAX_PES):
                        
                        ob_size = min(out_channels - ob_start, HWConfig.MAX_PES)
                        
                        bias_tile = bias_int[ob_start:ob_start+ob_size].cpu().numpy()
                        await self.driver.bias_setup(bias_tile, ob_size)
                        
                        for kh in range(Kh):
                            ih = oh * stride[0] + kh * dilation[0] - padding[0]
                            for kw in range(Kw):
                                
                                iw = ow * stride[1] + kw * dilation[1] - padding[1]
                                
                                if ih < 0 or ih >= H or iw < 0 or iw >= W:
                                    for ib_start in range(0, input_channel_group, HWConfig.MAX_INPUT_SIZE):
                                        ib_size = min(input_channel_group - ib_start, HWConfig.MAX_INPUT_SIZE)
                                        
                                        input_tile = np.full(ib_size, input_zp, dtype=np.uint8)
                                        weight_tile = q_weight_i8[ob_start:ob_start+ob_size, ib_start:ib_start+ib_size, kh, kw].cpu().numpy()
                                        
                                        await self.driver.hw_setup(input_tile, weight_tile, input_zp, ib_size, ob_size)
                                else:
                                    for ib_start in range(0, input_channel_group, HWConfig.MAX_INPUT_SIZE):
                                        ib_size = min(input_channel_group - ib_start, HWConfig.MAX_INPUT_SIZE)
                                        
                                        g = ob_start // (out_channels // groups)
                                        in_channel_start = g * input_channel_group + ib_start
                                        
                                        input_tile = q_input_u8[n, in_channel_start:in_channel_start+ib_size, ih, iw].view(-1).cpu().numpy()
                                        weight_tile = q_weight_i8[ob_start:ob_start+ob_size, ib_start:ib_start+ib_size, kh, kw].cpu().numpy()
                                        
                                        await self.driver.hw_setup(input_tile, weight_tile, input_zp, ib_size, ob_size)
                                        
                        out_tile = await self.driver.read_output(ob_size)
                        acc_out[n, ob_start:ob_start+ob_size, oh, ow] = torch.from_numpy(out_tile)
                        
        
        valid_input = torch.ones((1, input_channels, H, W), dtype=torch.float32)
        offset = F.conv2d(valid_input, q_weight_i8.float(), None, stride, padding, dilation, groups)
        offset = offset * (layer.qact.beta * scale).view(1, -1, 1, 1)
        
        self.output = acc_out.float() * alpha + offset