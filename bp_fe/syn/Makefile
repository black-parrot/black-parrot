## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

SYN_PATH    := $(BP_FE_DIR)/syn
TB_PATH     := $(BP_FE_DIR)/test/tb
LOG_PATH    := $(BP_FE_DIR)/syn/logs
REPORT_PATH := $(BP_FE_DIR)/syn/reports

# Default ROM to example
TB          ?= bp_fe_trace_demo
CFG         ?= e_bp_half_core_cfg

.EXPORT_ALL_VARIABLES:

include $(BP_COMMON_DIR)/syn/Makefile.common
include $(BP_COMMON_DIR)/syn/Makefile.dc
include $(BP_COMMON_DIR)/syn/Makefile.regress
include $(BP_COMMON_DIR)/syn/Makefile.verilator
include $(BP_COMMON_DIR)/syn/Makefile.vcs

regress.fe: regress
regress: check_design.syn
	#$(MAKE) lint.v || true
	#$(MAKE) lint.sc || true

