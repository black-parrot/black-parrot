## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

SYN_PATH    := $(BP_TOP_DIR)/syn
TB_PATH     := $(BP_TOP_DIR)/test/tb
LOG_PATH    := $(BP_TOP_DIR)/syn/logs
REPORT_PATH := $(BP_TOP_DIR)/syn/reports

# Default ROM to example
DESIGN_NAME ?= bp_multi_top
ROM_NAME    ?= bp_example_rom
TB          ?= bp_single_trace_demo

.EXPORT_ALL_VARIABLES:

include $(BP_COMMON_DIR)/syn/Makefile.common
include $(BP_COMMON_DIR)/syn/Makefile.dc
include $(BP_COMMON_DIR)/syn/Makefile.verilator
include $(BP_COMMON_DIR)/syn/Makefile.vcs

