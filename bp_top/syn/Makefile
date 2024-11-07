
## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)
include $(TOP)/Makefile.common
include $(TOP)/Makefile.env

export SYN_PATH     := $(BP_TOP_DIR)/syn
export TB_PATH      := $(BP_TOP_DIR)/test/tb

export LOG_PATH     := $(BP_TOP_DIR)/syn/logs
export RESULTS_PATH := $(BP_TOP_DIR)/syn/results
export REPORT_PATH  := $(BP_TOP_DIR)/syn/reports
export TOUCH_PATH   := $(BP_TOP_DIR)/syn/touchfiles

export TB    ?= bp_tethered
export CFG   ?= e_bp_default_cfg
export DRAM  ?= dramsim3
export SUITE ?= bp-tests
export PROG  ?= hello_world
export TAG   ?= none

export BUILD_COLLATERAL := %/flist.vcs %/wrapper.sv %/testbench.sv
export RUN_COLLATERAL := %/prog.nbf %/prog.mem %/prog.riscv
.PRECIOUS: $(BUILD_COLLATERAL) $(RUN_COLLATERAL)

include $(BP_RTL_MK_DIR)/Makefile.common

include $(TB_PATH)/$(TB)/Makefile.cfgs
include $(TB_PATH)/$(TB)/Makefile.collateral
include $(TB_PATH)/$(TB)/Makefile.params
include $(TB_PATH)/$(TB)/Makefile.testlist

