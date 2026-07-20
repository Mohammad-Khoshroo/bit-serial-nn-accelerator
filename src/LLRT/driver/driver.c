#include "driver.h"
#include "hal/include/eaiot_hal_mem.h"
#include "hal/include/eaiot_hal_io.h"
#include "llrt/hardware_config.h"

extern acc_driver_t popenhw_driver;

void hw_setup(uint8_t* input, int8_t* weight, int In_col, uint8_t input_zp, int i0, int o0) {


	eaiot_hal_mem_copy(popenhw_driver.iw_base_addr, input, i0);

	for (int oi = 0; oi < o0; oi++) {
		eaiot_hal_mem_copy(popenhw_driver.iw_base_addr + ((I0 + oi * I0)), weight + oi * In_col, i0);
	}
	int config_data;
	config_data = 0;
	config_data = ((o0 - 1) & 0xFFFF);
	eaiot_hal_Out32(popenhw_driver.config_base_addr + 4 , config_data);
	config_data = 0;
	config_data = ((input_zp & 0xFF) << 8) | (((i0 - 1) & 0xFFFF) << 16) | 1;
	eaiot_hal_Out32(popenhw_driver.config_base_addr, config_data);

	int done = 0;
	while(!done) {
		done = (eaiot_hal_In32((popenhw_driver.config_base_addr+4)) >> 16) & 0x1;
	}
	eaiot_hal_Out32(popenhw_driver.config_base_addr, 0);

}

void bias_setup(int* bias,int o0) {
	eaiot_hal_mem_copy(popenhw_driver.o_base_addr, bias , o0 * sizeof(int));
}

void recv_output(int* out,int o0) {
	eaiot_hal_mem_copy(out, popenhw_driver.o_base_addr, o0 * sizeof(int));
}

