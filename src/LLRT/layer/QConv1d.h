#ifndef __QCONV1D_H__
#define __QCONV1D_H__

#include "stdint.h"


void QConv1d(int* out, uint8_t* input, int8_t* weight, int* bias,
              uint8_t input_zp, int8_t weight_zp,
              int Lin, int Cin, int Cout, int K,
              int stride, int dilation,
              int pad_left, int pad_right, int groups);

#endif