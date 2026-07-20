#include "test_cases.h"
#include "llrt/tests/utils/test_utils.h"
#include "llrt/tests/ref/RQConv2d.h"
#include "llrt/layer/QConv2d.h"
#include "string.h"


void conv2d_test() {

    int H    = 16;
    int W    = 16;
    int Cin  = 8;
    int Cout = 16;
    int Kh   = 3;
    int Kw   = 3;
    int stride_h = 1;
    int stride_w = 1;
    int dilation_h = 1;
    int dilation_w = 1;
    int pad_top    = 1;
    int pad_bottom = 1;
    int pad_left   = 1;
    int pad_right  = 1;
    int groups = 2;

    int Cin_g = Cin / groups;
    int Hp = H + pad_top + pad_bottom;
    int Wp = W + pad_left + pad_right;
    int Hout = (Hp - (dilation_h * (Kh - 1) + 1)) / stride_h + 1;
    int Wout = (Wp - (dilation_w * (Kw - 1) + 1)) / stride_w + 1;

    uint8_t* input  = (uint8_t*) malloc(H * W * Cin * sizeof(uint8_t));
    int8_t*  weight = (int8_t*)  malloc(Cout * Kh * Kw * Cin_g * sizeof(int8_t));
    int*     bias   = (int*)     malloc(Cout * sizeof(int));
    int*     hw_out  = (int*) malloc(Hout * Wout * Cout * sizeof(int));
    int*     ref_out = (int*) malloc(Hout * Wout * Cout * sizeof(int));

    generate_random_int_array   (bias,   Cout,                      -1024, 1024);
    generate_random_int8_array  (weight, Cout * Kh * Kw * Cin_g,    -64, 64);
    generate_random_uint8_array (input,  H * W * Cin,               0, 128);

    uint8_t input_zp  = 100;
    int8_t  weight_zp = 0;

    QConv2d  (hw_out,  input, weight, bias, input_zp, weight_zp,
              H, W, Cin, Cout, Kh, Kw, stride_h, stride_w, dilation_h, dilation_w,
              pad_top, pad_bottom, pad_left, pad_right, groups);
    RQConv2d (ref_out, input, weight, bias, input_zp, weight_zp,
              H, W, Cin, Cout, Kh, Kw, stride_h, stride_w, dilation_h, dilation_w,
              pad_top, pad_bottom, pad_left, pad_right, groups);

    check_mem (hw_out, ref_out, Hout * Wout * Cout);

    free(input); free(weight); free(bias); free(hw_out); free(ref_out);
    return;
}