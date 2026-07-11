import torch
import torch.nn as nn

class LayerBase(nn.Module):
    def __init__(self, w_bit, a_bit, ltype='layer', *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.w_bit = w_bit
        self.a_bit = a_bit
        self.ltype = ltype
        self.param = {
            'w_bit': self.w_bit,
            'a_bit': self.a_bit,
        }

    def set_weight(self, weight, bias=None):
        self.weight = nn.Parameter(torch.tensor(weight))
        if bias is not None:
            self.bias = nn.Parameter(torch.tensor(bias))

    def qunatized_input(self, input):
        return input

    def qunatized_bias(self):
        if self.bias is not None:
            return self.bias

    def qunatized_weight(self):
        return self.weight

    def forward(self, x, **kwargs):
        return x
    
    def _load_from_state_dict(self, state_dict, prefix, local_metadata, strict, missing_keys, unexpected_keys, error_msgs):
        if not torch.onnx.is_in_onnx_export():
            self.param = state_dict.pop(prefix + 'param', None)
            self.ltype = state_dict.pop(prefix + 'type', None)
        super()._load_from_state_dict(state_dict, prefix, local_metadata, strict, missing_keys, unexpected_keys, error_msgs)
    
