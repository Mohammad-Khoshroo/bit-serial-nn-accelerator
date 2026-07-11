import copy
import math
from typing import List, Optional
import torch
import torch.nn as nn
import torch.nn.functional as F
from torch.autograd import Function
from layers import LayerBase
from onnx_quant import *

EVAL_BASE = False #false to simulate real quantization

class Round(Function):
    @staticmethod
    def forward(self, input):
        sign = torch.sign(input)
        output = sign * torch.floor(torch.abs(input) + 0.5)
        return output

    @staticmethod
    def backward(self, grad_output):
        grad_input = grad_output.clone()
        return grad_input

class _AsymQuantSTE(torch.autograd.Function):
    @staticmethod
    def forward(ctx, x, s_raw, beta, n: int, p: int):
        s_eff = s_raw.abs().clamp(min=1e-12)
        t = (x - beta) / s_eff
        q = Round.apply(t).clamp(n, p)
        xhat = q * s_eff + beta
        ctx.save_for_backward(x, s_eff, beta, q, s_raw.sign(), (s_eff >= 1e-12).to(x.dtype))
        ctx.n, ctx.p = n, p
        return xhat, q.detach()

    @staticmethod
    def backward(ctx, grad_out, grad_q):
        x, s_eff, beta, q, s_sign, s_mask = ctx.saved_tensors
        n, p = ctx.n, ctx.p
        t = (x - beta) / s_eff

        below = (t < n).to(grad_out.dtype)
        above = (t > p).to(grad_out.dtype)
        within = 1.0 - below - above

        grad_x = within * grad_out
        d_s_eff = within * (q - t) + below * n + above * p
        d_beta = 1.0 - within

        # reduce back to param shapes
        def reduce_like(g, like):
            while g.ndim > like.ndim:
                g = g.sum(dim=0)
            for i, (gs, ls) in enumerate(zip(g.shape, like.shape)):
                if ls == 1 and gs != 1:
                    g = g.sum(dim=i, keepdim=True)
            return g

        grad_s_eff = reduce_like(d_s_eff * grad_out, s_eff)
        grad_beta  = reduce_like(d_beta  * grad_out, beta)

        # LSQ(+ ) scaling
        elems_per_param = q.numel() // s_eff.numel()
        g = (elems_per_param * float(p)) ** -0.5
        grad_s_eff = grad_s_eff * g
        grad_beta  = grad_beta  * g

        grad_s_raw = grad_s_eff * s_sign * s_mask

        return grad_x, grad_s_raw, grad_beta, None, None
    
class LSQPlusActivationQuantizer(nn.Module):
    def __init__(self, a_bit, all_positive=False,batch_init = 20):
        super(LSQPlusActivationQuantizer, self).__init__()
        self.a_bit = a_bit
        self.all_positive = all_positive
        self.batch_init = batch_init
        if self.all_positive:
            # unsigned activation is quantized to [0, 2^b-1]
            self.Qn = 0
            self.Qp = 2 ** a_bit - 1
        else:
            # signed weight/activation is quantized to [-2^(b-1), 2^(b-1)-1]
            self.Qn = - 2 ** (a_bit - 1)
            self.Qp = 2 ** (a_bit - 1) - 1
        self.s = torch.nn.Parameter(torch.zeros(1), requires_grad=True)
        self.beta = torch.nn.Parameter(torch.zeros(1), requires_grad=True)
        self.register_buffer('init_state', torch.zeros(1))
        # LSQ+ MSE-based initialization hyper-parameters (Sec. 3.2.2).
        self.init_iters = 50
        self.init_lr = 1e-2

    def _load_from_state_dict(self, state_dict, prefix, local_metadata, strict,
                              missing_keys, unexpected_keys, error_msgs):
        for name in ("s", "beta"):
            key = prefix + name
            if key in state_dict and state_dict[key].ndim == 0:
                state_dict[key] = state_dict[key].reshape(1)
        super()._load_from_state_dict(
            state_dict, prefix, local_metadata, strict,
            missing_keys, unexpected_keys, error_msgs,
        )

    @torch.no_grad()
    def _minmax_seed(self, x: torch.Tensor):
        """Min-max seed for (s, β) (Eq. 7): maps [x_min, x_max] -> [Qn, Qp]."""
        x_min, x_max = x.min(), x.max()
        s = torch.clamp((x_max - x_min) / float(self.Qp - self.Qn), min=1e-8)
        beta = x_min - self.Qn * s
        self.s.copy_(s.reshape_as(self.s))
        self.beta.copy_(beta.reshape_as(self.beta))

    def init_quant_params(self, x: torch.Tensor):
        self._minmax_seed(x)
        xb = x.detach()

        def mse():
            xhat, _ = _AsymQuantSTE.apply(xb, self.s, self.beta, self.Qn, self.Qp)
            return (xhat - xb).pow(2).mean()

        # Keep the best (s, β) seen so the refinement can never do worse than the
        # min-max seed (Adam can overshoot for the tiny-magnitude scale parameter).
        with torch.no_grad():
            best_loss = mse()
            best_s, best_beta = self.s.detach().clone(), self.beta.detach().clone()

        m = [torch.zeros_like(self.s), torch.zeros_like(self.beta)]
        v = [torch.zeros_like(self.s), torch.zeros_like(self.beta)]
        b1, b2, eps = 0.9, 0.999, 1e-8
        for t in range(1, self.init_iters + 1):
            loss = mse()
            grads = torch.autograd.grad(loss, [self.s, self.beta])
            with torch.no_grad():
                for i, (param, g) in enumerate(zip((self.s, self.beta), grads)):
                    m[i] = b1 * m[i] + (1 - b1) * g
                    v[i] = b2 * v[i] + (1 - b2) * g * g
                    mhat = m[i] / (1 - b1 ** t)
                    vhat = v[i] / (1 - b2 ** t)
                    param.data = param.data - self.init_lr * mhat / (vhat.sqrt() + eps)
                self.s.data.clamp_(min=1e-8)
                cur = mse()
                if cur < best_loss:
                    best_loss = cur
                    best_s, best_beta = self.s.detach().clone(), self.beta.detach().clone()

        with torch.no_grad():
            self.s.data.copy_(best_s)
            self.beta.data.copy_(best_beta)
        self.init_state += 1

    def forward(self, activation):
        if self.a_bit == 32:
            q_a = activation
        elif self.a_bit == 1:
            print('！Binary quantization is not supported ！')
            assert self.a_bit != 1
        else:
            if self.init_state < 1 and self.training:
                self.init_quant_params(activation)
            q_a, qa = _AsymQuantSTE.apply(activation, self.s, self.beta, self.Qn, self.Qp)
            if not EVAL_BASE and not self.training:
                return qa
        return q_a

class LSQPlusWeightQuantizer(nn.Module):
    def __init__(self, w_bit, all_positive=False, per_channel=False, batch_init = 20, shape=(1,), saved=True):
        super(LSQPlusWeightQuantizer, self).__init__()
        self.w_bit = w_bit
        self.s_bits = 20
        self.n = 1 << 16
        self.all_positive = all_positive
        self.batch_init = batch_init
        if self.all_positive:
            # unsigned activation is quantized to [0, 2^b-1]
            self.Qn = 0
            self.Qp = 2 ** w_bit - 1
        else:
            # signed weight/activation is quantized to [-2^(b-1), 2^(b-1)-1]
            self.Qn = - 2 ** (w_bit - 1)
            self.Qp = 2 ** (w_bit - 1) - 1
        self.per_channel = per_channel
        self.register_buffer('init_state', torch.zeros(1))
        if not per_channel:
            # Per-tensor (per-layer) step size: a single scalar, as in LSQ/LSQ+.
            self.s = torch.nn.Parameter(torch.zeros(1), requires_grad=True)
        else:
            # Per-(output-)channel step size.
            self.s = torch.nn.Parameter(torch.zeros(shape[0]), requires_grad=True)

        self.saved = saved
        if saved:
            self.register_buffer("wq", torch.ones(shape, dtype=torch.float32))
    
    @torch.no_grad()
    def init_scale(self, weight):
        W = weight.detach()
        C_out = W.shape[0]
        denom = 2 ** (self.w_bit - 1)  # note: denominator is 2^(b-1) per paper

        if self.per_channel:
            mu = W.view(C_out, -1).mean(dim=1, keepdim=True)
            sigma = W.view(C_out, -1).std(dim=1, unbiased=False, keepdim=True)
            lo = (mu - 3 * sigma).abs()
            hi = (mu + 3 * sigma).abs()
            rng = torch.maximum(lo, hi).view(C_out)
            
            s = rng / denom
            s = torch.clamp(s, min=1e-8)
            self.s.data = s * 0.9 + self.s.data * 0.1
        else:
            mu = W.mean()
            sigma = W.std(unbiased=False)
            rng = torch.maximum((mu - 3 * sigma).abs(), (mu + 3 * sigma).abs())
            s = torch.clamp(rng / denom, min=1e-8)
            self.s.data = s.reshape_as(self.s.data) * 0.9 + self.s.data * 0.1

        self.init_state += 1
      
    def forward(self, weight):
        if self.w_bit == 32:
            w_q = weight
        elif self.w_bit == 1:
            print('！Binary quantization is not supported ！')
            assert self.w_bit != 1
        else:
            if self.init_state < self.batch_init and self.training:
                self.init_scale(weight)
            s_w_expand = self.s
            if self.per_channel:
                if len(weight.shape) > 2:
                    if len(weight.shape) == 3:
                        s_w_expand = self.s.view(weight.shape[0], 1, 1)
                    else:
                        s_w_expand = self.s.view(weight.shape[0], 1, 1, 1)
                else:
                    s_w_expand = self.s.view(-1, 1)
                    
            # w_q, wq = _SignMagQuantSTE.apply(weight, s_w_expand, self.Qp)
            w_q, wq = _AsymQuantSTE.apply(weight, s_w_expand, torch.zeros_like(s_w_expand), self.Qn, self.Qp)
            
            self.wq.copy_(wq)
            if not EVAL_BASE and not self.training:
                return wq
        return w_q

class LSQPQuantize(LayerBase):
    def __init__(self, w_bit, a_bit, ltype='layer', all_positive=False, per_channel=True, batch_init=20, wshape=(1,), quant_inference=False, **kwargs):
        super().__init__(w_bit, a_bit, 'lsqp' + ltype, **kwargs)
        self.quant_inference = quant_inference
        self.all_positive = all_positive
        self.qw = LSQPlusWeightQuantizer(w_bit, False, per_channel, batch_init, wshape, saved=True)

        if self.a_bit > 0:
            self.qact = LSQPlusActivationQuantizer(a_bit, all_positive, batch_init)

    def qunatized_input(self, input):
        if torch.onnx.is_in_onnx_export():
            return ActOnnxQuant.apply(input, self.qact.s, self.qact.beta, self.a_bit, int(self.qact.all_positive))
        if self.a_bit > 0:
            return self.qact(input)
        return input
            
    def qunatized_weight(self):
        if torch.onnx.is_in_onnx_export():
            if not self.quant_inference:
                with torch.no_grad():
                    self.qw(self.weight)
            return self.qw.wq
        if not self.quant_inference:
            return self.qw(self.weight)
        return self.weight
    
    def set_dequant_params(self):
        pass

    def _weight_scale(self) -> torch.Tensor:
        return self.qw.s.abs().clamp(min=1e-12)

    def _activation_scale(self) -> torch.Tensor:
        return self.qact.s.abs().clamp(min=1e-12)

    def _full_conv2d_offset(self, x, quant_weight, sc, shape):
        valid = torch.ones(
            (1, x.shape[1], x.shape[2], x.shape[3]),
            device=quant_weight.device,
            dtype=quant_weight.dtype,
        )
        offset = F.conv2d(valid, quant_weight, None, self.stride,
                          self.padding, self.dilation, self.groups)
        return offset * (self.qact.beta * sc).view(*shape)

    def _full_conv1d_offset(self, x, quant_weight, sc, shape):
        valid = torch.ones(
            (1, x.shape[1], x.shape[2]),
            device=quant_weight.device,
            dtype=quant_weight.dtype,
        )
        offset = F.conv1d(valid, quant_weight, None, self.stride,
                          self.padding, self.dilation, self.groups)
        return offset * (self.qact.beta * sc).view(*shape)

    def _compact_same_pad3x3_offset(self, output, quant_weight, sc, alpha):
        beta_sc = self.qact.beta * sc

        def scaled_sum(weight_slice):
            return (beta_sc * weight_slice.sum(dim=(1, 2, 3))).view(1, -1, 1, 1)

        center = scaled_sum(quant_weight)
        top = scaled_sum(quant_weight[:, :, 1:, :])
        bottom = scaled_sum(quant_weight[:, :, :-1, :])
        left = scaled_sum(quant_weight[:, :, :, 1:])
        right = scaled_sum(quant_weight[:, :, :, :-1])
        top_left = scaled_sum(quant_weight[:, :, 1:, 1:])
        top_right = scaled_sum(quant_weight[:, :, 1:, :-1])
        bottom_left = scaled_sum(quant_weight[:, :, :-1, 1:])
        bottom_right = scaled_sum(quant_weight[:, :, :-1, :-1])

        out = output * alpha + center
        out[:, :, 0:1, :] += top - center
        out[:, :, -1:, :] += bottom - center
        out[:, :, :, 0:1] += left - center
        out[:, :, :, -1:] += right - center
        out[:, :, 0:1, 0:1] += top_left - top - left + center
        out[:, :, 0:1, -1:] += top_right - top - right + center
        out[:, :, -1:, 0:1] += bottom_left - bottom - left + center
        out[:, :, -1:, -1:] += bottom_right - bottom - right + center
        return out

    def _can_use_compact_same_pad3x3(self, output, quant_weight):
        return (
            quant_weight.ndim == 4
            and tuple(quant_weight.shape[2:]) == (3, 3)
            and tuple(self.padding) == (1, 1)
            and tuple(self.stride) == (1, 1)
            and tuple(self.dilation) == (1, 1)
            and output.shape[-2] > 1
            and output.shape[-1] > 1
        )

    def _compact_same_pad3_offset(self, output, quant_weight, sc, alpha):
        beta_sc = self.qact.beta * sc

        def scaled_sum(weight_slice):
            return (beta_sc * weight_slice.sum(dim=(1, 2))).view(1, -1, 1)

        center = scaled_sum(quant_weight)
        left = scaled_sum(quant_weight[:, :, 1:])
        right = scaled_sum(quant_weight[:, :, :-1])

        out = output * alpha + center
        out[:, :, 0:1] += left - center
        out[:, :, -1:] += right - center
        return out

    def _can_use_compact_same_pad3(self, output, quant_weight):
        return (
            quant_weight.ndim == 3
            and quant_weight.shape[2] == 3
            and tuple(self.padding) == (1,)
            and tuple(self.stride) == (1,)
            and tuple(self.dilation) == (1,)
            and output.shape[-1] > 1
        )
        
    
class QuantConv2d(LSQPQuantize, nn.Conv2d):
    def __init__(self,
                 in_channels,
                 out_channels,
                 kernel_size,
                 stride=1,
                 padding=0,
                 dilation=1,
                 groups=1,
                 bias=True,
                 padding_mode='zeros',
                 a_bit=8,
                 w_bit=8,
                 quant_inference=False,
                 all_positive=False, 
                 per_channel=False,
                 batch_init = 20,
                 **kwargs):
        super().__init__(in_channels=in_channels,
                         out_channels=out_channels,
                         kernel_size=kernel_size,
                         stride=stride,
                         padding=padding,
                         dilation=dilation,
                         groups=groups,
                         bias=bias,
                         padding_mode=padding_mode,
                         w_bit=w_bit, a_bit=a_bit,
                         all_positive=all_positive,
                         per_channel=per_channel,
                         batch_init=batch_init,
                         quant_inference=quant_inference,
                         wshape=(out_channels, in_channels // groups, *kernel_size),
                         ltype='conv2d', **kwargs)
    def forward(self, x):
        quant_weight = self.qunatized_weight()
        quant_input = self.qunatized_input(x)
        if EVAL_BASE or (self.training and not torch.onnx.is_in_onnx_export()):
            output = F.conv2d(quant_input, quant_weight, self.bias, self.stride,
                    padding=self.padding, groups=self.groups, dilation=self.dilation)
        if not EVAL_BASE and not self.training:
            output = Conv2dOnnxQuant.apply(quant_input, quant_weight, self.stride,
                    self.padding, self.groups, self.dilation, self.w_bit, int(self.all_positive))
            shape = [1] * output.ndim
            shape[1] = -1
            sc = self._weight_scale()
            alpha = (sc * self._activation_scale()).view(*shape)

            self.alpha = alpha.detach()
            if not torch.onnx.is_in_onnx_export():
                if self._can_use_compact_same_pad3x3(output, quant_weight):
                    output = self._compact_same_pad3x3_offset(output, quant_weight, sc, alpha)
                else:
                    offset = self._full_conv2d_offset(x, quant_weight, sc, shape)
                    output = output * alpha + offset
                if self.bias is not None:
                    output = output + self.bias.view(*shape)
                return output
            offset = self._full_conv2d_offset(x, quant_weight, sc, shape)
            if self.bias is not None:
                offset = offset + self.bias.view(*shape)
            self.offset = offset.detach()
            output = ActOnnxDeQuant.apply(output, self.alpha, self.offset)
        return output


class QuantLinear(LSQPQuantize, nn.Linear):
    def __init__(self,
                 in_features,
                 out_features,
                 bias=True,
                 a_bit=8,
                 w_bit=8,
                 quant_inference=False, 
                 all_positive=False, 
                 per_channel=False,
                 batch_init = 20,
                 **kwargs):
        super().__init__(in_features=in_features,
                 out_features=out_features,
                 bias=bias,
                 a_bit=a_bit,
                 w_bit=w_bit,
                 quant_inference=quant_inference, 
                 all_positive=all_positive, 
                 per_channel=per_channel,
                 batch_init=batch_init,
                 wshape=(out_features, in_features),
                 ltype='linear', **kwargs)
    def forward(self, input):
        quant_weight = self.qunatized_weight()
        quant_input = self.qunatized_input(input)
        if EVAL_BASE or (self.training and not torch.onnx.is_in_onnx_export()):
            output = F.linear(quant_input, quant_weight, self.bias)
        if not EVAL_BASE and not self.training:
            output = LinearOnnxQuant.apply(quant_input, quant_weight, self.w_bit, int(self.all_positive))

            view_shape = [1] * (output.dim() - 1) + [-1]
            sc = self._weight_scale()
            alpha = (sc * self._activation_scale()).view(*view_shape)

            # Bias folding term: beta * s_w * sum_j q_w_ij.
            w_sum = quant_weight.sum(dim=1)
            offset = self.qact.beta * sc * w_sum
            if self.bias is not None:
                offset = offset + self.bias
            offset = offset.view(*view_shape)

            self.alpha = alpha.detach()
            self.offset = offset.detach()
            if not torch.onnx.is_in_onnx_export():
                return output * self.alpha + self.offset
            output = ActOnnxDeQuant.apply(output, self.alpha, self.offset)
        return output
