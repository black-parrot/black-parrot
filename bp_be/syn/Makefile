## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

SYN_PATH := $(BP_BE_DIR)/syn
TB_PATH  := $(BP_BE_DIR)/test/tb
LOG_PATH := $(BP_BE_DIR)/syn/logs

# Default ROM to example
ROM_NAME ?= bp_example_rom
TB       ?= bp_be_trace_demo

.EXPORT_ALL_VARIABLES:

include $(BP_COMMON_DIR)/syn/Makefile.common
include $(BP_COMMON_DIR)/syn/Makefile.dc
include $(BP_COMMON_DIR)/syn/Makefile.verilator
include $(BP_COMMON_DIR)/syn/Makefile.vcs

