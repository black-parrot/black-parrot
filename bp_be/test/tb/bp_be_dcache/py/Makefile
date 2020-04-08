## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

clean:
	rm -rf test_*

generate_tests:
	python3 trace_script.py 

double_word_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py test_sd_ld.tr mem_test_trace_rom > ../mem_test_trace_rom.v

word_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py test_sw_lw.tr mem_test_trace_rom > ../mem_test_trace_rom.v

half_word_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py test_sh_lh.tr mem_test_trace_rom > ../mem_test_trace_rom.v

byte_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py test_sb_lb.tr mem_test_trace_rom > ../mem_test_trace_rom.v

writeback_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py test_wb.tr mem_test_trace_rom > ../mem_test_trace_rom.v

uncached_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py test_uncached.tr mem_test_trace_rom > ../mem_test_trace_rom.v

unaligned_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py test_unaligned.tr mem_test_trace_rom > ../mem_test_trace_rom.v

