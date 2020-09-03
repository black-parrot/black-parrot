## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

export SYN_PATH     := $(BP_BE_DIR)/syn
export TB_PATH      := $(BP_BE_DIR)/test/tb

export LOG_PATH     := $(BP_BE_DIR)/syn/logs
export RESULTS_PATH := $(BP_BE_DIR)/syn/results
export REPORT_PATH  := $(BP_BE_DIR)/syn/reports
export TOUCH_PATH   := $(BP_BE_DIR)/syn/touchfiles

export TB    ?= bp_be_dcache
export CFG   ?= e_bp_unicore_half_cfg
export SUITE ?= none
export PROG  ?= double_word_test
export TAG   ?= none

-include $(BP_TEST_DIR)/Makefile.tests
-include $(TB_PATH)/$(TB)/Makefile.cfgs
-include $(TB_PATH)/$(TB)/Makefile.params
-include $(TB_PATH)/$(TB)/Makefile.testlist
-include $(BP_COMMON_DIR)/syn/Makefile.common
-include $(BP_COMMON_DIR)/syn/Makefile.dc
-include $(BP_COMMON_DIR)/syn/Makefile.verilator
-include $(BP_COMMON_DIR)/syn/Makefile.vcs

