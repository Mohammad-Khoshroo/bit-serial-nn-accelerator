#ifndef __TEST_UTILS_H__
#define __TEST_UTILS_H__

#include "stdint.h"

void generate_random_float_array(float *arr, int size, float min, float max);
float random_float(float min, float max);

int random_int(int min,int max);
void generate_random_int_array(int* arr, int size, int min, int max);
void generate_random_uint8_array(uint8_t* arr, int size, int min, int max);
void generate_random_int8_array(int8_t* arr, int size, int min, int max);

int check_mem(int* mem_a, int* golden_mem, int len);
int check_mem_8(uint8_t* mem_a, uint8_t* golden_mem, int len);
int check_mem_float(float* mem_a, float* golden_mem, int len);


#endif