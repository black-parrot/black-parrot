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
	$(MAKE) run.$(_TS) PROG=$*

