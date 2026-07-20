#include "QGemm.h"
#include "llrt/hardware_config.h"
#include "llrt/driver/driver.h"
#include "llrt/utils.h"


void QGemm(int* out, uint8_t* input, int8_t* weight, int* bias, uint8_t input_zp , int8_t weight_zp, int In_row, int In_col, int Out_col) {

	for (int ir=0; ir < In_row; ir += 1) {
		for (int oc = 0; oc < Out_col; oc+=O0) {
			int o0 = LLRT_MIN(Out_col - oc, O0);
			bias_setup(bias + ir * Out_col + oc, o0);
			for (int ic = 0; ic < In_col; ic+=I0) {
				int i0 = LLRT_MIN(I0, In_col - ic);

				hw_setup(input + ir * In_col + ic, weight + oc * In_col + ic, In_col, input_zp, i0, o0);
			}
			recv_output(out + ir * Out_col + oc, o0);
		}
	}
}
