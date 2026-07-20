#include "Padding.h"



// Pads input with input_zp on each side independently
uint8_t* pad_input_1d(uint8_t* input, int Lin, int Cin,
                       int pad_left, int pad_right,
                       uint8_t input_zp, int* Lin_padded) {
    int Lp = Lin + pad_left + pad_right;
    *Lin_padded = Lp;
    uint8_t* padded = (uint8_t*) malloc(Lp * Cin * sizeof(uint8_t));
    for (int i = 0; i < Lp * Cin; i++) padded[i] = input_zp;
    for (int l = 0; l < Lin; l++)
        for (int c = 0; c < Cin; c++)
            padded[(l + pad_left) * Cin + c] = input[l * Cin + c];
    return padded;
}



uint8_t* pad_input_2d(uint8_t* input, int H, int W, int Cin,
                       int pad_top, int pad_bottom, int pad_left, int pad_right,
                       uint8_t input_zp, int* Hp_out, int* Wp_out) {
    int Hp = H + pad_top + pad_bottom;
    int Wp = W + pad_left + pad_right;
    *Hp_out = Hp;
    *Wp_out = Wp;
    uint8_t* padded = (uint8_t*) malloc(Hp * Wp * Cin * sizeof(uint8_t));
    for (int i = 0; i < Hp * Wp * Cin; i++) padded[i] = input_zp;
    for (int h = 0; h < H; h++)
        for (int w = 0; w < W; w++)
            for (int c = 0; c < Cin; c++)
                padded[((h + pad_top) * Wp + (w + pad_left)) * Cin + c] =
                    input[(h * W + w) * Cin + c];
    return padded;
}