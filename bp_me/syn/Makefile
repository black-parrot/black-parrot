## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

SYN_PATH    := $(BP_ME_DIR)/syn
TB_PATH     := $(BP_ME_DIR)/test/tb
LOG_PATH    := $(BP_ME_DIR)/syn/logs
REPORT_PATH := $(BP_ME_DIR)/syn/reports

# Default ROM to example
DESIGN_NAME ?= bp_me_top
TB          ?= bp_me_trace_demo

## End specific flags and variables
BP_ME_SRC_PATH       = $(BP_ME_DIR)/src/v
BP_ME_INC_PATH       = $(BP_ME_DIR)/src/include/v
BP_ME_TB_PATH        = $(BP_ME_DIR)/test
BP_ME_TB_COMMON_PATH = $(BP_ME_TB_PATH)/common
BP_ME_SYN_PATH       = $(BP_ME_DIR)/syn
CCE_ROM_PATH         = $(BP_ME_SRC_PATH)/roms
CCE_SRC_PATH         = $(BP_ME_SRC_PATH)/cce
NETWORK_PATH         = $(BP_ME_SRC_PATH)/network

# C includes used by verilator
CPPFLAGS += -I$(BP_ME_TB_PATH)/include -I$(BP_ME_DIR)/src/include/c

.EXPORT_ALL_VARIABLES:

include $(BP_COMMON_DIR)/syn/Makefile.common
include $(BP_COMMON_DIR)/syn/Makefile.dc
include $(BP_COMMON_DIR)/syn/Makefile.regress
include $(BP_COMMON_DIR)/syn/Makefile.verilator
include $(BP_COMMON_DIR)/syn/Makefile.vcs

regress: regress.me
regress.me: 
	$(MAKE) lint.v || true
	$(MAKE) lint.sc || true
	$(MAKE) -C $(BP_ME_DIR)/test/tb/bp_me_random_demo \
	| tee -i $(LOG_PATH)/vcs/bp_me_random_stress_test.log
	@grep "mBPC" $(LOG_PATH)/vcs/bp_me_random_stress_test.log \
	| tee -i $(REPORT_PATH)/vcs/bp_me_random_stress_test.rpt
	@grep "mBPC" $(LOG_PATH)/vcs/bp_me_random_stress_test.log \
	|| echo "FAILED" >> $(REPORT_DIR)/bp_me_random_stress_test.err

