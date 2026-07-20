#ifndef __QLinear_H__
#define __QLinear_H__

#include "stdint.h"

void QGemm(int* out, uint8_t* input, int8_t* weight, int* bias, uint8_t input_zp , int8_t weight_zp, int In_row, int In_col, int Out_col);

#endif
