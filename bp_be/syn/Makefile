## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

export SYN_PATH     := $(BP_BE_DIR)/syn
export TB_PATH      := $(BP_BE_DIR)/test/tb
export MEM_PATH     := $(BP_BE_DIR)/test/tb/mem

export LOG_PATH     := $(BP_BE_DIR)/syn/logs
export RESULTS_PATH := $(BP_BE_DIR)/syn/results
export REPORT_PATH  := $(BP_BE_DIR)/syn/reports

TB           ?= bp_be_dcache
CFG          ?= e_bp_half_core_cfg
UCE          ?= 1
WRITETHROUGH ?= 0
RANDOM_YUMI  ?= 0

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

LIST         ?= /dev/null
LIST_PROGS   := $(shell cat $(LIST))
NUM_TESTS    := $(shell cat $(LIST) | wc -l)
PYTHON_DIR   := $(TB_PATH)/$(TB)/py

ifeq ($(UCE), 0)
	CE=CCE
else
	CE=UCE
endif

ifeq ($(WRITETHROUGH), 0)
	CA=WB
else
	CA=WT
endif

regress.list.sc:
	$(MAKE) generate_tests
	$(MAKE) build.sc UCE_P=$(UCE) WRITETHROUGH_P=$(WRITETHROUGH) RANDOM_YUMI_P=$(RANDOM_YUMI) REGRESS_P=1
	$(MAKE) regress.list.tests _TS=sc _T=verilator
	touch reports/verilator/final.rpt
	@printf "Tests passed for $(CA) cache with $(CE) (out of $(NUM_TESTS)): " >> reports/verilator/final.rpt
	@grep -r FINISH reports/verilator/$(TB).$(CFG).sim.$(CE)_$(CA).*.rpt | wc -l >> reports/verilator/final.rpt
	cat reports/verilator/final.rpt

regress.list.v:
	$(MAKE) generate_tests
	$(MAKE) build.v UCE_P=$(UCE) WRITETHROUGH_P=$(WRITETHROUGH) RANDOM_YUMI_P=$(RANDOM_YUMI) REGRESS_P=1
	$(MAKE) regress.list.tests _TS=v _T=vcs
	touch reports/vcs/final.rpt
	@printf "Tests passed for $(CA) cache with $(CE) (out of $(NUM_TESTS)): " >> reports/vcs/final.rpt
	@grep -r FINISH reports/vcs/$(TB).$(CFG).sim.$(CE)_$(CA).*.rpt | wc -l >> reports/vcs/final.rpt
	cat reports/vcs/final.rpt

regress.list.tests: $(foreach p, $(LIST_PROGS), regress.list.run.$p)

regress.list.run.%:
	$(MAKE) sim.v PROG=$*
	@cp logs/$(_T)/$(TB).$(CFG).sim.$*.log logs/$(_T)/$(TB).$(CFG).sim.$(CE)_$(CA).$*.log
	@grep -i FINISH logs/$(_T)/$(TB).$(CFG).sim.$(CE)_$(CA).$*.log > reports/$(_T)/$(TB).$(CFG).sim.$(CE)_$(CA).$*.rpt
