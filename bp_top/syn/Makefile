## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

export SYN_PATH     := $(BP_TOP_DIR)/syn
export TB_PATH      := $(BP_TOP_DIR)/test/tb

export LOG_PATH     := $(BP_TOP_DIR)/syn/logs
export RESULTS_PATH := $(BP_TOP_DIR)/syn/results
export REPORT_PATH  := $(BP_TOP_DIR)/syn/reports
export TOUCH_PATH   := $(BP_TOP_DIR)/syn/touchfiles

export TB    ?= bp_tethered
export CFG   ?= e_bp_softcore_cfg
export SUITE ?= bp_tests
export PROG  ?= hello_world
export TAG   ?= none

include $(BP_TEST_DIR)/Makefile.tests
include $(TB_PATH)/$(TB)/Makefile.params
include $(TB_PATH)/$(TB)/Makefile.testlist
include $(BP_COMMON_DIR)/syn/Makefile.common
include $(BP_COMMON_DIR)/syn/Makefile.dc
include $(BP_COMMON_DIR)/syn/Makefile.regress
include $(BP_COMMON_DIR)/syn/Makefile.verilator
include $(BP_COMMON_DIR)/syn/Makefile.vcs

regress.top: regress
regress: regress.v check_design.syn
	$(MAKE) lint.v || true
	$(MAKE) lint.sc || true

LIST ?= /dev/null
LIST_PROGS = $(shell cat $(LIST))

regress.list.sc:
	$(MAKE) regress.list.common _TS=sc
	($(foreach p, $(LIST_PROGS), echo $p; echo "=========="; cat reports/verilator/$(TB).$(CFG).sim.$p.rpt; echo "";)) | tee -i reports/verilator/$(TB).$(CFG).$@.rpt

regress.list.v:
	$(MAKE) regress.list.common _TS=v
	($(foreach p, $(LIST_PROGS), echo $p; echo "=========="; cat reports/vcs/$(TB).$(CFG).sim.$p.rpt; echo "";)) | tee -i reports/vcs/$(TB).$(CFG).$@.rpt

regress.list.common:
	$(MAKE) build.$(_TS)
	$(MAKE) regress.list.common.run_in_parallel

regress.list.common.run_in_parallel: $(foreach p, $(LIST_PROGS), regress.list.common.launch_run.$p)

regress.list.common.launch_run.%:
	$(MAKE) sim.$(_TS) SUITE=beebs PROG=$*

