#include "test_utils.h"
#include "stdlib.h"



int check_mem_float(float* mem_a, float* golden_mem, int len) {
    float data_a, data_golden;
    int error = 0;
    for(int i = 0; i < len; i++) {
        data_a = mem_a[i];
        data_golden = golden_mem[i];
        if (data_golden - data_a) {
            error++;
            printf("Error at data %d \n\t\tGolden:%f\n\t\tData:%f\n", i, data_golden, data_a);
        }
    }
    return error;
}

int check_mem(int* mem_a, int* golden_mem, int len) {
    int data_a, data_golden;
    int error = 0;
    for(int i = 0; i < len; i++) {
        data_a = mem_a[i];
        data_golden = golden_mem[i];
        if (data_golden - data_a) {
            error++;
            printf("Error at data %d \n\t\tGolden:%d\n\t\tData:%d\n", i, data_golden, data_a);
        }
    }
    return error;
}

int check_mem_8(uint8_t* mem_a, uint8_t* golden_mem, int len) {
    uint8_t data_a, data_golden;
    int error = 0;
    for(int i = 0; i < len; i++) {
        data_a = mem_a[i];
        data_golden = golden_mem[i];
        if (data_golden != data_a) {
            error++;
            printf("Error at data %u \n\t\tGolden:%u\n\t\tData:%u\n", i, data_golden, data_a);
        }
    }
    return error;
}

float random_float(float min, float max) {
    return min + ((float)rand() / RAND_MAX) * (max - min);
}

int random_int(int min,int max) {
    return min + (int)(((float)rand() / RAND_MAX) * (max - min));
}

void generate_random_float_array(float *arr, int size, float min, float max) {
    for (int i = 0; i < size; i++) {
        arr[i] = random_float(min, max);
    }
}

void generate_random_int_array(int* arr, int size, int min, int max) {
    for (int i = 0; i < size; i++) {
        arr[i] = random_int(min, max);
    }
}

void generate_random_uint8_array(uint8_t* arr, int size, int min, int max) {
    for (int i = 0; i < size; i++) {
        arr[i] = (uint8_t) random_int(min, max);
    }
}

void generate_random_int8_array(int8_t* arr, int size, int min, int max) {
    for (int i = 0; i < size; i++) {
        arr[i] = (int8_t) random_int(min, max);
    }
}

