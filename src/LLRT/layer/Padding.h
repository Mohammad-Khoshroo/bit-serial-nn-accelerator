#ifndef __PADDING_H__
#define __PADDING_H__

#include "stdint.h"

uint8_t* pad_input_1d(uint8_t* input, int Lin, int Cin,
                       int pad_left, int pad_right,
                       uint8_t input_zp, int* Lin_padded);



uint8_t* pad_input_2d(uint8_t* input, int H, int W, int Cin,
                       int pad_top, int pad_bottom, int pad_left, int pad_right,
                       uint8_t input_zp, int* Hp_out, int* Wp_out);

#endif