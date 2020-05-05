## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

export TB_PATH := $(BP_FE_DIR)/test/tb
export TB = bp_fe_icache

clean_tests:
	rm -rf $(TB_PATH)/$(TB)/py/*.tr
	rm -rf $(TB_PATH)/$(TB)/mem_test_trace_rom.v

generate_tests:
	python3 $(TB_PATH)/$(TB)/py/trace_script.py $(TB_PATH) $(TB)

load_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/test_load.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

uncached_load_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/test_uncached_load.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v
