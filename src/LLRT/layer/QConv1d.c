#include "QConv1d.h"
#include "llrt/hardware_config.h"
#include "llrt/driver/driver.h"
#include "llrt/utils.h"
#include "llrt/layer/Padding.h"


void QConv1d(int* out, uint8_t* input, int8_t* weight, int* bias,
              uint8_t input_zp, int8_t weight_zp,
              int Lin, int Cin, int Cout, int K,
              int stride, int dilation,
              int pad_left, int pad_right, int groups) {

    int Lin_p;
    uint8_t* padded = pad_input_1d(input, Lin, Cin, pad_left, pad_right, input_zp, &Lin_p);
    int Lout = (Lin_p - (dilation * (K - 1) + 1)) / stride + 1;

    int Cin_g  = Cin  / groups;
    int Cout_g = Cout / groups;
    int row_stride = K * Cin_g;

    for (int op = 0; op < Lout; op += 1) {
        for (int oc = 0; oc < Cout; oc += O0) {
            int o0 = LLRT_MIN(Cout - oc, O0);
            bias_setup(bias + oc, o0);

            for (int k = 0; k < K; k += 1) {
                int in_pos = op * stride + k * dilation;
                for (int ic = 0; ic < Cin_g; ic += I0) {
                    int i0 = LLRT_MIN(I0, Cin_g - ic);
                    int g = oc / Cout_g; // assumes O0 <= Cout_g
                    int in_ch = g * Cin_g + ic;
                    hw_setup(padded + in_pos * Cin + in_ch,
                             weight + oc * row_stride + k * Cin_g + ic,
                             row_stride, input_zp, i0, o0);
                }
            }
            recv_output(out + op * Cout + oc, o0);
        }
    }

    free(padded);
}