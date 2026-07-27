# Defaults
SIM_BUILD ?= build
RESULTS_FILE ?= results.xml dump.vcd
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(shell find hardware -type f -name '*.v' -o -name '*.sv')
COMPILE_ARGS += -Ihardware/include
EXTRA_ARGS += --trace --timing -Wno-ASCRANGE -Wno-WIDTHEXPAND -Wno-WIDTHTRUNC -Wno-CASEINCOMPLETE -Wno-COMBDLY -Wno-LATCH -Wno-UNOPTFLAT

# select the terget arch
# COCOTB_TOPLEVEL = cluster_wrapper
# COCOTB_TOPLEVEL = cluster_wrapper_bit_serial
COCOTB_TOPLEVEL = cluster_wrapper_bit_sparsity

COCOTB_TEST_MODULES = test_bench

include $(shell cocotb-config --makefiles)/Makefile.sim


.PHONY: clean

.PHONY: clean

clean::
	@echo "Cleaning build artifacts and caches..."
	@rm -rf $(SIM_BUILD)
	@mkdir -p $(SIM_BUILD)
	@touch $(SIM_BUILD)/.gitkeep
	@find . -type d -name '__pycache__' -exec rm -rf {} + 2>/dev/null || true
	@rm -f $(RESULTS_FILE)
	@echo "Clean complete."