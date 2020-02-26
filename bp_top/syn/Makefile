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
#TB          ?= bp_processor
CFG         ?= e_bp_single_core_cfg
START_PC    ?= 0x80000000
TOLERANCE   ?= 2

COH_PROTO   ?= mesi
CCE_MEM_PATH = $(BP_ME_DIR)/src/asm/roms/$(COH_PROTO)
CCE_MEM      = bp_cce_inst_rom_$(COH_PROTO).mem

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

