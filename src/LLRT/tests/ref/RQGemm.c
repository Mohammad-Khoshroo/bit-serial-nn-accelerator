#include "RQGemm.h"
#include "llrt/hardware_config.h"
#include "llrt/driver/driver.h"
#include "math.h"
#include "llrt/utils.h"


void RQGemm(int* out, uint8_t* input, int8_t* weight, int* bias, uint8_t input_zp , int8_t weight_zp, int In_row, int In_col, int Out_col) {

	for (int ir=0; ir < In_row; ir += 1) {
		for (int oc = 0; oc < Out_col; oc += 1) {
			int temp = bias[ir * Out_col + oc];
			for (int ic = 0; ic < In_col; ic+= 1) {
				temp += (((int)input[ir * In_col + ic]) - ((int) input_zp)) * (int) weight [ oc * In_col + ic] ;
			}
			out[ir * Out_col + oc] = temp;
		}
	}
}
