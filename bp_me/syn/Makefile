## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)
include $(TOP)/Makefile.common
include $(TOP)/Makefile.env

export SYN_PATH    := $(BP_ME_DIR)/syn
export TB_PATH     := $(BP_ME_DIR)/test/tb

export LOG_PATH     := $(BP_ME_DIR)/syn/logs
export REPORT_PATH  := $(BP_ME_DIR)/syn/reports
export RESULTS_PATH := $(BP_ME_DIR)/syn/results
export TOUCH_PATH   := $(BP_ME_DIR)/syn/touchfiles

## End specific flags and variables
export TB    ?= bp_cce
export CFG   ?= e_bp_test_multicore_half_cfg
export DRAM  ?= dramsim3
export SUITE ?= cce
export PROG  ?= none
export TAG   ?= none

export BUILD_COLLATERAL ?= %/flist.vcs %/wrapper.sv %/testbench.sv
export RUN_COLLATERAL ?= %/test.tr %/cce_ucode.mem
.PRECIOUS: $(BUILD_COLLATERAL) $(RUN_COLLATERAL)

include $(BP_RTL_MK_DIR)/Makefile.common

include $(TB_PATH)/$(TB)/Makefile.cfgs
include $(TB_PATH)/$(TB)/Makefile.collateral
include $(TB_PATH)/$(TB)/Makefile.params
include $(TB_PATH)/$(TB)/Makefile.testlist

