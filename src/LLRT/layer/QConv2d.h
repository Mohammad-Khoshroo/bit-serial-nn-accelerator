#ifndef __QCONV2D_H__
#define __QCONV2D_H__

#include "stdint.h"


void QConv2d(int* out, uint8_t* input, int8_t* weight, int* bias,
              uint8_t input_zp, int8_t weight_zp,
              int H, int W, int Cin, int Cout, int Kh, int Kw,
              int stride_h, int stride_w, int dilation_h, int dilation_w,
              int pad_top, int pad_bottom, int pad_left, int pad_right, int groups);
              

#endif
