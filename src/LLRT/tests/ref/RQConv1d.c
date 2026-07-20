#include "RQConv1d.h"
#include "llrt/layer/Padding.h"

void RQConv1d(int* out, uint8_t* input, int8_t* weight, int* bias,
               uint8_t input_zp, int8_t weight_zp,
               int Lin, int Cin, int Cout, int K,
               int stride, int dilation,
               int pad_left, int pad_right, int groups) {

    int Lin_p;
    uint8_t* padded = pad_input_1d(input, Lin, Cin, pad_left, pad_right, input_zp, &Lin_p);
    int Lout = (Lin_p - (dilation * (K - 1) + 1)) / stride + 1;

    int Cin_g  = Cin  / groups;
    int Cout_g = Cout / groups;

    for (int op = 0; op < Lout; op += 1) {
        for (int oc = 0; oc < Cout; oc += 1) {
            int g = oc / Cout_g;
            int temp = bias[oc];
            for (int k = 0; k < K; k += 1) {
                int in_pos = op * stride + k * dilation;
                for (int ic = 0; ic < Cin_g; ic += 1) {
                    int in_ch = g * Cin_g + ic;
                    temp += (((int)padded[in_pos * Cin + in_ch]) - (int)input_zp)
                            * (int)weight[oc * K * Cin_g + k * Cin_g + ic];
                }
            }
            out[op * Cout + oc] = temp;
        }
    }

    free(padded);
}