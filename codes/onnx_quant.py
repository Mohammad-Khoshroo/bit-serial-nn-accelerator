import torch
from torch.nn.modules.utils import _pair
import torch.nn.functional as F
import onnx
from torch.onnx import symbolic_helper as sym_help
    
class ActOnnxQuant(torch.autograd.Function):
    @staticmethod
    def forward(ctx,
                input: torch.Tensor,
                s: torch.Tensor,
                beta: torch.Tensor,
                nbit: int,          # NOTE: python ints, not tensors
                positive: int) -> torch.Tensor:
        s_eff = s.abs().clamp(min=1e-12)
        t = (input - beta) / s_eff
        q = torch.sign(t) * torch.floor(torch.abs(t) + 0.5)
        if positive:
            qn, qp = 0, 2 ** int(nbit) - 1
        else:
            qn, qp = -(2 ** (int(nbit) - 1)), 2 ** (int(nbit) - 1) - 1
        return q.clamp(qn, qp)

    @staticmethod
    def backward(ctx, grad_output):
        # input, s, beta, nbit, positive
        return grad_output, None, None, None, None

    @staticmethod
    def symbolic(g,
                 input: torch.Value,
                 s: torch.Value,
                 beta: torch.Value,
                 nbit: int,
                 positive: int) -> torch.Value:

        y = g.op("MYDOMAIN::act_quant",
                 input, s, beta,
                 a_bit_i=int(nbit),
                 positive_i=int(positive))
        y.setType(input.type())
        return y
    
class ActOnnxDeQuant(torch.autograd.Function):
    @staticmethod
    def forward(ctx, input: torch.Tensor, alpha: torch.Tensor, offset: torch.Tensor) -> torch.Tensor:
        return input * alpha + offset
    
    @staticmethod
    def backward(ctx, grad_output):
        return grad_output, None, None
    
    @staticmethod
    def symbolic(g: torch.Graph, input: torch.Value, alpha: torch.Value, offset: torch.Value) -> torch.Value:
        y = g.op("MYDOMAIN::act_dequant", input, alpha, offset)
        y.setType(input.type())

        return y
    
class Conv2dOnnxQuant(torch.autograd.Function):
    @staticmethod
    def forward(ctx, x, weight, stride, padding, groups, dilation, wbit, positive) -> torch.Tensor:
        return F.conv2d(x, weight,
                        stride=stride,
                        padding=padding,
                        groups=groups,
                        dilation=dilation)
    
    @staticmethod
    def backward(ctx, grad_output):
        return grad_output, None
    
    @staticmethod
    def symbolic(g, x, weight, stride, padding, groups, dilation, wbit, positive):
        bits = sym_help._maybe_get_const(wbit, 'i')
        if sym_help._is_value(bits):
            # still a graph Value -> cannot use in an attribute
            raise RuntimeError("wbit must be a constant integer at ONNX export time.")
        bits = int(bits)
        to_dtype = int(onnx.TensorProto.INT8 if bits <= 8 else onnx.TensorProto.INT16)
        w = g.op("Cast", weight, to_i=to_dtype)

        # 2) Normalize conv params
        sh, sw = _pair(stride)
        ph, pw = _pair(padding)
        dh, dw = _pair(dilation)

        # 3) Extract known sizes
        x_sizes = getattr(x.type(), "sizes", lambda: None)()  # [N, Cin, Hin, Win] or None
        w_sizes = getattr(weight.type(), "sizes", lambda: None)()  # [Cout, Cin/groups, Kh, Kw] or None

        # We require static kernel spatial dims (same as your original check)
        if not (w_sizes and len(w_sizes) >= 4 and w_sizes[2] is not None and w_sizes[3] is not None):
            raise RuntimeError("ConvOnnxQuant symbolic requires statically known kernel spatial dimensions.")
        kh, kw = int(w_sizes[2]), int(w_sizes[3])

        # 4) Emit your custom op
        y = g.op(
            "MYDOMAIN::QConv", x, w,
            strides_i=[int(sh), int(sw)],
            pads_i=[int(ph), int(pw), int(ph), int(pw)],
            group_i=int(groups),
            dilations_i=[int(dh), int(dw)],
            kernel_shape_i=[kh, kw],
            positive_i=int(positive)
        )

        # 5) Compute/assign output shape + dtype (this is what silences the warning)
        def _dim_out(H, K, S, P, D):
            if H is None:
                return None
            # Standard conv output formula (no ceil_mode)
            return (int(H) + 2*int(P) - int(D)*(int(K) - 1) - 1) // int(S) + 1

        N = x_sizes[0] if (x_sizes and len(x_sizes) > 0) else None
        Cout = w_sizes[0] if (w_sizes and len(w_sizes) > 0) else None
        Hin = x_sizes[2] if (x_sizes and len(x_sizes) > 2) else None
        Win = x_sizes[3] if (x_sizes and len(x_sizes) > 3) else None
        Hout = _dim_out(Hin, kh, sh, ph, dh)
        Wout = _dim_out(Win, kw, sw, pw, dw)

        # Set the rank and as many dims as we know: [N, Cout, Hout, Wout]
        # Keep dtype = input dtype (typical for quantized-weight convs)
        try:
            # Preferred: use the TensorType API when available
            out_type = x.type().with_sizes([N, Cout, Hout, Wout])
            # Keep the same scalar dtype as x (with_dtype may not exist on older versions)
            if hasattr(out_type, "with_dtype") and hasattr(x.type(), "scalarType") and x.type().scalarType() is not None:
                out_type = out_type.with_dtype(x.type().scalarType())
            y.setType(out_type)
        except Exception:
            # Fallback for older PyTorch: use exporter helper
            try:
                sym_help._set_output_types(y, [x.type().with_sizes([N, Cout, Hout, Wout])])
            except Exception:
                # Last resort: at least fix the rank so the warning goes away
                rank4 = [N, Cout, Hout, Wout]
                y.setType(x.type().with_sizes(rank4))

        return y
    
class LinearOnnxQuant(torch.autograd.Function):
    @staticmethod
    def forward(ctx, x, weight, wbit, positive):
        return F.linear(x, weight, None)
    
    @staticmethod
    def backward(ctx, grad_output):
        return grad_output, None
    
    @staticmethod
    def symbolic(g, x, weight, wbit, positive):
        to_dtype = int(onnx.TensorProto.INT8 if (isinstance(wbit, int) and wbit <= 8) else onnx.TensorProto.INT16)
        weight_transposed = g.op("Transpose", weight, perm_i=[1, 0])
        w = g.op("Cast", weight_transposed, to_i=to_dtype)
        
        x_sizes = getattr(x.type(), "sizes", lambda: None)() 
        w_sizes = getattr(weight.type(), "sizes", lambda: None)()
        
        if not (w_sizes and len(w_sizes) >= 2):
            raise RuntimeError("LinearOnnxQuant symbolic requires statically known kernel spatial dimensions.")

        y = g.op(
            "MYDOMAIN::QMatMul", x, w,
            positive_i=int(positive)
        )
        try:
            y_sizes = None
            if isinstance(x_sizes, (list, tuple)) and len(x_sizes) >= 1:
                y_sizes = list(x_sizes)
                y_sizes[-1] = w_sizes[0]

            y_t = x.type()
            # Preserve dtype if available
            if hasattr(y_t, "with_dtype") and callable(getattr(y_t, "with_dtype")) and hasattr(y_t, "dtype"):
                y_t = y_t.with_dtype(y_t.dtype())

            # Set sizes if we could compute them
            if y_sizes is not None and hasattr(y_t, "with_sizes"):
                y_t = y_t.with_sizes(y_sizes)

            y.setType(y_t)
        except Exception:
            # Best-effort fallback: at least keep dtype of x
            if hasattr(x.type(), "with_dtype") and hasattr(x.type(), "dtype"):
                y.setType(x.type().with_dtype(x.type().dtype()))
            # If that also isn't possible, we leave type inference to downstream passes

        return y
        
        