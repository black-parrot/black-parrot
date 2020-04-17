## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

export TB_PATH      := $(BP_BE_DIR)/test/tb
export TB           := bp_be_dcache

clean_tests:
	rm -rf $(TB_PATH)/$(TB)/py/*.tr
	rm -rf $(TB_PATH)/$(TB)/py/*rom.v

generate_tests:
	python3 $(TB_PATH)/$(TB)/py/trace_script.py $(TB_PATH) $(TB)

double_word_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/test_sd_ld.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

word_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/test_sw_lw.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

half_word_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/test_sh_lh.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

byte_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/test_sb_lb.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

writeback_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/test_wb.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

uncached_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/test_uncached.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

unaligned_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/test_unaligned.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

wt_test_1: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/test_writethrough1.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

wt_test_2: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/test_writethrough2.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

wt_test_3: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/test_writethrough3.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v
