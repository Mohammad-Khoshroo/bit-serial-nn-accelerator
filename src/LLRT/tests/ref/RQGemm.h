#ifndef __RQLinear_H__
#define __RQLinear_H__

#include "stdint.h"

void RQGemm(int* out, uint8_t* input, int8_t* weight, int* bias, uint8_t input_zp , int8_t weight_zp, int In_row, int In_col, int Out_col);

#endif
