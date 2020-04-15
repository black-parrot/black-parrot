## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

export SYN_PATH     := $(BP_FE_DIR)/syn
export TB_PATH      := $(BP_FE_DIR)/test/tb
export MEM_PATH     := $(BP_FE_DIR)/test/tb

export LOG_PATH     := $(BP_FE_DIR)/syn/logs
export RESULTS_PATH := $(BP_FE_DIR)/syn/results
export REPORT_PATH  := $(BP_FE_DIR)/syn/reports

TB          ?= bp_fe_icache
CFG         ?= e_bp_half_core_cfg
START_PC    ?= 0x80000000
TOLERANCE   ?= 2

DRAMSIM_CH_CFG  ?= DDR2_micron_16M_8b_x8_sg3E.ini
DRAMSIM_SYS_CFG ?= system.ini

include $(BP_COMMON_DIR)/syn/Makefile.common
include $(BP_COMMON_DIR)/syn/Makefile.dc
include $(BP_COMMON_DIR)/syn/Makefile.regress
include $(BP_COMMON_DIR)/syn/Makefile.verilator
include $(BP_COMMON_DIR)/syn/Makefile.vcs
include $(BP_COMMON_DIR)/syn/Makefile.sv2v
include $(TB_PATH)/$(TB)/py/Makefile

regress.top: regress
regress: regress.v check_design.syn
	$(MAKE) lint.v || true
	$(MAKE) lint.sc || true

LIST ?= /dev/null
LIST_PROGS = $(shell cat $(LIST))
NUM_TESTS = $(shell cat $(LIST) | wc -l)

regress.list.sc:
	$(MAKE) regress.list.common _TS=sc _T=verilator
	cat reports/verilator/final.rpt
regress.list.v:
	$(MAKE) regress.list.common _TS=v _T=vcs
	cat reports/vcs/final.rpt

regress.list.common:
	$(MAKE) regress.list.common.tests
	touch reports/$(_T)/final.rpt
	printf "Tests passed for cache with CCE (out of $(NUM_TESTS)): " >> reports/$(_T)/final.rpt
	grep -r FINISH reports/$(_T)/$(TB).$(CFG).sim.cce.* | wc -l >> reports/$(_T)/final.rpt
	
	printf "Tests passed for cache with UCE (out of $(NUM_TESTS)): " >> reports/$(_T)/final.rpt
	grep -r FINISH reports/$(_T)/$(TB).$(CFG).sim.uce.* | wc -l >> reports/$(_T)/final.rpt
	
regress.list.common.tests: $(foreach p, $(LIST_PROGS), regress.list.common.build_and_run.$p)

regress.list.common.build_and_run.%:
	$(MAKE) $*
	rm -rf results/$(_T)/*
	rm -rf logs/$(_T)/*
	$(MAKE) build.$(_TS) UCE_P=0
	$(MAKE) run.$(_TS)
	grep FINISH logs/$(_T)/$(TB).$(CFG).sim.$(PROG).log >> reports/$(_T)/$(TB).$(CFG).sim.cce.$*.rpt
	
	rm -rf results/$(_T)/*
	rm -rf logs/$(_T)/*
	$(MAKE) build.$(_TS) UCE_P=1
	$(MAKE) run.$(_TS)
	grep FINISH logs/$(_T)/$(TB).$(CFG).sim.$(PROG).log >> reports/$(_T)/$(TB).$(CFG).sim.uce.$*.rpt
