# Defaults
SIM_BUILD ?= build
RESULTS_FILE ?= results.xml
SIM ?= verilator
TOPLEVEL_LANG ?= verilog

VERILOG_SOURCES += $(shell find hardware -type f -name '*.v' -o -name '*.sv')
COMPILE_ARGS += -Ihardware/include
EXTRA_ARGS += --trace --timing


COCOTB_TOPLEVEL = cluster_wrapper
COCOTB_TEST_MODULES = test_bench

include $(shell cocotb-config --makefiles)/Makefile.sim