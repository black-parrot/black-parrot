## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

SYN_PATH    := $(BP_TOP_DIR)/syn
TB_PATH     := $(BP_TOP_DIR)/test/tb
MEM_PATH    := $(BP_COMMON_DIR)/test/mem
LOG_PATH    := $(BP_TOP_DIR)/syn/logs
REPORT_PATH := $(BP_TOP_DIR)/syn/reports
RUN_PATH    := $(BP_TOP_DIR)/syn/run

# Default ROM to example
TB          ?= bp_top_trace_demo
CFG         ?= e_bp_single_core_cfg

.EXPORT_ALL_VARIABLES:

include $(BP_COMMON_DIR)/syn/Makefile.common
include $(BP_COMMON_DIR)/syn/Makefile.dc
include $(BP_COMMON_DIR)/syn/Makefile.regress
include $(BP_COMMON_DIR)/syn/Makefile.verilator
include $(BP_COMMON_DIR)/syn/Makefile.vcs

regress.top: regress
regress: regress.v check_design.syn
	$(MAKE) lint.v || true
	$(MAKE) lint.sc || true

