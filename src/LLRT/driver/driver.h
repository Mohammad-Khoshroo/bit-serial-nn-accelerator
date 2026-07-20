#ifndef __DRIVER_H__
#define __DRIVER_H__

#include "stdint.h"

void hw_setup(uint8_t* input, int8_t* weight, int In_col, uint8_t input_zp, int i0, int o0);
void bias_setup(int* bias,int o0);
void recv_output(int* out,int o0);

typedef struct {
    uintptr_t config_base_addr;
    uintptr_t iw_base_addr;
    uintptr_t o_base_addr;

} acc_driver_t;

#endif
