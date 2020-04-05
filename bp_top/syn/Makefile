## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

export SYN_PATH     := $(BP_TOP_DIR)/syn
export TB_PATH      := $(BP_TOP_DIR)/test/tb
export MEM_PATH     := $(BP_COMMON_DIR)/test/mem

export LOG_PATH     := $(BP_TOP_DIR)/syn/logs
export RESULTS_PATH := $(BP_TOP_DIR)/syn/results
export REPORT_PATH  := $(BP_TOP_DIR)/syn/reports

TB          ?= bp_softcore
CFG         ?= e_bp_softcore_cfg

COH_PROTO   ?= mesi
CCE_MEM_PATH = $(BP_ME_DIR)/src/asm/roms/$(COH_PROTO)
CCE_MEM      = bp_cce_inst_rom_$(COH_PROTO).mem

DRAMSIM_CH_CFG  ?= DDR3_micron_32M_8B_x8_sg25E.ini
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

