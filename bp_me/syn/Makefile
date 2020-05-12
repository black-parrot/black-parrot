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
export CFG   ?= e_bp_half_core_cfg
export SUITE ?= cce
export PROG  ?= none
export TAG   ?= none

include $(BP_TEST_DIR)/Makefile.tests
include $(TB_PATH)/$(TB)/Makefile.params
include $(TB_PATH)/$(TB)/Makefile.testlist
include $(BP_COMMON_DIR)/syn/Makefile.common
include $(BP_COMMON_DIR)/syn/Makefile.dc
include $(BP_COMMON_DIR)/syn/Makefile.verilator
include $(BP_COMMON_DIR)/syn/Makefile.vcs

regress.me.sc: dirs.sc
	$(MAKE) -j 1 build.sc sim.sc TB=bp_cce NUM_INSTR_P=$(NUM_INSTR_P) PROG=normal
	$(MAKE) -j 1 build.sc sim.sc TB=bp_cce NUM_INSTR_P=$(NUM_INSTR_P) SKIP_INIT_P=1 PROG=uncached
	$(MAKE) -j 1 build.sc sim.sc TB=bp_cce_fsm NUM_INSTR_P=$(NUM_INSTR_P) PROG=normal
	$(MAKE) -j 1 build.sc sim.sc TB=bp_cce_fsm NUM_INSTR_P=$(NUM_INSTR_P) SKIP_INIT_P=1 PROG=uncached

regress.me.v: dirs.v
	$(MAKE) -j 1 build.v sim.v TB=bp_cce NUM_INSTR_P=$(NUM_INSTR_P) PROG=normal
	$(MAKE) -j 1 build.v sim.v TB=bp_cce NUM_INSTR_P=$(NUM_INSTR_P) SKIP_INIT_P=1 PROG=uncached
	$(MAKE) -j 1 build.v sim.v TB=bp_cce_fsm NUM_INSTR_P=$(NUM_INSTR_P) PROG=normal
	$(MAKE) -j 1 build.v sim.v TB=bp_cce_fsm NUM_INSTR_P=$(NUM_INSTR_P) SKIP_INIT_P=1 PROG=uncached

regress: regress.me
regress.me: lint.me regress.me.sc regress.me.v

regress_full.me.v:
	./run-me.sh

clean: clean.me
clean.me:
	rm -f *.axe

# NOTE: targets below are not up to date
#axe: AXE_LOG ?= ./axe.log
#axe:
#	python $(BP_ME_DIR)/software/py/axe_trace_filter.py $(AXE_LOG) > trace.axe
#	cat trace.axe
#	axe check TSO trace.axe


