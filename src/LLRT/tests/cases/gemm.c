#include "test_cases.h"
#include "llrt/tests/utils/test_utils.h"
#include "llrt/tests/ref/RQGemm.h"
#include "llrt/layer/QGemm.h"
#include "string.h"

void gemm_test() {
    
    int In_row  = 32;
//    int In_row  = random_int (1, 16);
    int In_col  = 64;
//    int In_col  = random_int (1, 32);
    int Out_col = 64;
//    int Out_col = random_int (1, 64);



    uint8_t*    input   = (uint8_t*)    malloc (In_row * In_col * sizeof(uint8_t));
    int8_t*     weight  = (int8_t*)     malloc (In_col * Out_col * sizeof(int8_t));
    int*        bias    = (int*)        malloc (In_row * Out_col * sizeof(int));
    int*        hw_out  = (int*)        malloc (In_row * Out_col * sizeof(int));
    int*        ref_out = (int*)        malloc (In_row * Out_col * sizeof(int));


    generate_random_int_array   (bias, In_row * Out_col , -1024, 1024);
    generate_random_int8_array  (weight, In_col * Out_col, -64, 64);
    generate_random_uint8_array (input, In_row * In_col, 0, 128);

//    uint8_t input_zp = (uint8_t) random_int(0, 255);
    uint8_t input_zp = 100;

    int8_t  weight_zp = 0;



    QGemm (hw_out, input, weight, bias, input_zp , weight_zp, In_row, In_col, Out_col);

    RQGemm (ref_out, input, weight, bias, input_zp , weight_zp, In_row, In_col, Out_col);

    check_mem (hw_out, ref_out, In_row * Out_col);

    return;
}
