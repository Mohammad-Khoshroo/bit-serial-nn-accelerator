#include "test_cases.h"
#include "llrt/tests/utils/test_utils.h"
#include "llrt/tests/ref/RQConv1d.h"
#include "llrt/layer/QConv1d.h"
#include "string.h"



void conv1d_test() {

    int Lin   = 32;
    int Cin   = 16;
    int Cout  = 32;
    int K     = 3;
    int stride   = 1;
    int dilation = 1;
    int pad_left  = 1;
    int pad_right = 1;
    int groups   = 2;

    int Cin_g = Cin / groups;
    int Lin_p = Lin + pad_left + pad_right;
    int Lout  = (Lin_p - (dilation * (K - 1) + 1)) / stride + 1;

    uint8_t* input  = (uint8_t*) malloc(Lin  * Cin  * sizeof(uint8_t));
    int8_t*  weight = (int8_t*)  malloc(Cout * K * Cin_g * sizeof(int8_t));
    int*     bias   = (int*)     malloc(Cout * sizeof(int));
    int*     hw_out  = (int*) malloc(Lout * Cout * sizeof(int));
    int*     ref_out = (int*) malloc(Lout * Cout * sizeof(int));

    generate_random_int_array   (bias,   Cout,               -1024, 1024);
    generate_random_int8_array  (weight, Cout * K * Cin_g,   -64, 64);
    generate_random_uint8_array (input,  Lin * Cin,          0, 128);

    uint8_t input_zp  = 100;
    int8_t  weight_zp = 0;

    QConv1d  (hw_out,  input, weight, bias, input_zp, weight_zp,
              Lin, Cin, Cout, K, stride, dilation, pad_left, pad_right, groups);
    RQConv1d (ref_out, input, weight, bias, input_zp, weight_zp,
              Lin, Cin, Cout, K, stride, dilation, pad_left, pad_right, groups);

    check_mem (hw_out, ref_out, Lout * Cout);

    free(input); free(weight); free(bias); free(hw_out); free(ref_out);
    return;
}
