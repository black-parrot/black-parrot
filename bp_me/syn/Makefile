## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

export SYN_PATH    := $(BP_ME_DIR)/syn
export TB_PATH     := $(BP_ME_DIR)/test/tb

export LOG_PATH     := $(BP_ME_DIR)/syn/logs
export REPORT_PATH  := $(BP_ME_DIR)/syn/reports
export RESULTS_PATH := $(BP_ME_DIR)/syn/results
export TOUCH_PATH   := $(BP_ME_DIR)/syn/touchfiles

## End specific flags and variables
export TB    ?= bp_cce
export CFG   ?= e_bp_multicore_half_cfg
export SUITE ?= cce
export PROG  ?= none
export TAG   ?= none

-include $(BP_TEST_DIR)/Makefile.tests
-include $(TB_PATH)/$(TB)/Makefile.cfgs
-include $(TB_PATH)/$(TB)/Makefile.params
-include $(TB_PATH)/$(TB)/Makefile.testlist
-include $(BP_COMMON_DIR)/syn/Makefile.common
-include $(BP_COMMON_DIR)/syn/Makefile.dc
-include $(BP_COMMON_DIR)/syn/Makefile.verilator
-include $(BP_COMMON_DIR)/syn/Makefile.vcs

