#include "RQConv2d.h"
#include "llrt/layer/Padding.h"

void RQConv2d(int* out, uint8_t* input, int8_t* weight, int* bias,
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

    for (int oh = 0; oh < Hout; oh += 1) {
        for (int ow = 0; ow < Wout; ow += 1) {
            for (int oc = 0; oc < Cout; oc += 1) {
                int g = oc / Cout_g;
                int temp = bias[oc];
                for (int kh = 0; kh < Kh; kh += 1) {
                    int ih = oh * stride_h + kh * dilation_h;
                    for (int kw = 0; kw < Kw; kw += 1) {
                        int iw = ow * stride_w + kw * dilation_w;
                        for (int ic = 0; ic < Cin_g; ic += 1) {
                            int in_ch = g * Cin_g + ic;
                            temp += (((int)padded[(ih * Wp + iw) * Cin + in_ch]) - (int)input_zp)
                                    * (int)weight[oc * Kh * Kw * Cin_g + (kh * Kw + kw) * Cin_g + ic];
                        }
                    }
                }
                out[(oh * Wout + ow) * Cout + oc] = temp;
            }
        }
    }

    free(padded);
}