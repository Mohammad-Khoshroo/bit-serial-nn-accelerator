#include "QConv2d.h"
#include "llrt/hardware_config.h"
#include "llrt/driver/driver.h"
#include "llrt/utils.h"
#include "llrt/layer/Padding.h"

/***
 * Layout: I assumed channel-last (NLC/NHWC) for input/output and [Cout][K][Cin]/[Cout][Kh][Kw][Cin] for weights,
 *  since that's what makes both hw_setup operands contiguous. If your weights are actually stored channel-first ([Cout][Cin][K]),
 *  the access pattern can't directly map to contiguous hw_setup calls without an im2col-style repack
 */



void QConv2d(int* out, uint8_t* input, int8_t* weight, int* bias,
              uint8_t input_zp, int8_t weight_zp,
              int H, int W, int Cin, int Cout, int Kh, int Kw,
              int stride_h, int stride_w, int dilation_h, int dilation_w,
              int pad_top, int pad_bottom, int pad_left, int pad_right, int groups) {

    int Hp, Wp;
    uint8_t* padded = pad_input_2d(input, H, W, Cin, pad_top, pad_bottom, pad_left, pad_right,
                                    input_zp, &Hp, &Wp);
    int Hout = (Hp - (dilation_h * (Kh - 1) + 1)) / stride_h + 1;
    int Wout = (Wp - (dilation_w * (Kw - 1) + 1)) / stride_w + 1;

    int Cin_g  = Cin  / groups;
    int Cout_g = Cout / groups;
    int row_stride = Kh * Kw * Cin_g;

    for (int oh = 0; oh < Hout; oh += 1) {
        for (int ow = 0; ow < Wout; ow += 1) {
            for (int oc = 0; oc < Cout; oc += O0) {
                int o0 = LLRT_MIN(Cout - oc, O0);
                bias_setup(bias + oc, o0);

                for (int kh = 0; kh < Kh; kh += 1) {
                    int ih = oh * stride_h + kh * dilation_h;
                    for (int kw = 0; kw < Kw; kw += 1) {
                        int iw = ow * stride_w + kw * dilation_w;
                        for (int ic = 0; ic < Cin_g; ic += I0) {
                            int i0 = LLRT_MIN(I0, Cin_g - ic);
                            int g = oc / Cout_g; // assumes O0 <= Cout_g
                            int in_ch = g * Cin_g + ic;
                            hw_setup(padded + (ih * Wp + iw) * Cin + in_ch,
                                     weight + oc * row_stride + (kh * Kw + kw) * Cin_g + ic,
                                     row_stride, input_zp, i0, o0);
                        }
                    }
                }
                recv_output(out + (oh * Wout + ow) * Cout + oc, o0);
            }
        }
    }

    free(padded);
}