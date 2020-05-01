## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

TB_PATH      := $(BP_BE_DIR)/test/tb
MEM_PATH     := $(BP_BE_DIR)/test/tb/mem
TB           := bp_be_dcache

clean_tests:
	rm -rf $(TB_PATH)/$(TB)/py/*.tr
	rm -rf $(MEM_PATH)/*.mem
	rm -rf $(TB_PATH)/$(TB)/py/*rom.v

generate_tests:
	mkdir -p $(TB_PATH)/mem
	python3 $(TB_PATH)/$(TB)/py/trace_script.py $(TB_PATH) $(TB) $(MEM_PATH)

double_word_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/double_word_test.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

word_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/word_test.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

half_word_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/half_word_test.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

byte_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/byte_test.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

writeback_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/writeback_test.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

uncached_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/uncached_test.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

unaligned_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/unaligned_test.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

wt_test_1: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/wt_test_1.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

wt_test_2: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/wt_test_2.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v

wt_test_3: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $(TB_PATH)/$(TB)/py/wt_test_3.tr mem_test_trace_rom > $(TB_PATH)/$(TB)/mem_test_trace_rom.v
