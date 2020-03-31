## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

clean:
	rm -rf test_*

generate_tests:
	python3 trace_script.py 

load_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py test_load.tr mem_test_trace_rom > ../mem_test_trace_rom.v

uncached_load_test: generate_tests
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py test_uncached_load.tr mem_test_trace_rom > ../mem_test_trace_rom.v
