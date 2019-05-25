## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

SYN_PATH     := $(BP_TOP_DIR)/syn
TB_PATH      := $(BP_TOP_DIR)/test/tb
MEM_PATH     := $(BP_COMMON_DIR)/test/mem

LOG_PATH     := $(BP_TOP_DIR)/syn/logs
RESULTS_PATH := $(BP_TOP_DIR)/syn/results
REPORT_PATH  := $(BP_TOP_DIR)/syn/reports

# Default ROM to example
TB          ?= bp_top_trace_demo
CFG         ?= e_bp_single_core_cfg

# Select CCE ROM based on CFG and Coherence Protocol
ifeq ($(CFG), e_bp_half_core_cfg)
  NUM_LCE_P=1
  N_WG=64
else ifeq ($(CFG), e_bp_single_core_cfg)
  NUM_LCE_P=2
  N_WG=64
else ifeq ($(CFG), e_bp_dual_core_cfg)
  NUM_LCE_P=4
  N_WG=32
else ifeq ($(CFG), e_bp_quad_core_cfg)
  NUM_LCE_P=8
  N_WG=16
else ifeq ($(CFG), e_bp_oct_core_cfg)
  NUM_LCE_P=16
  N_WG=8
endif

COH_PROTO   ?= mesi
CCE_ROM_PATH = $(BP_ME_DIR)/src/v/roms/$(COH_PROTO)-tr
CCE_ROM      = bp_cce_inst_rom_$(COH_PROTO)-tr_lce$(NUM_LCE_P)_wg$(N_WG)_assoc8.v

DRAMSIM_CH_CFG  ?= DDR2_micron_16M_8b_x8_sg3E.ini
DRAMSIM_SYS_CFG ?= system.ini

.EXPORT_ALL_VARIABLES:

include $(BP_COMMON_DIR)/syn/Makefile.common
include $(BP_COMMON_DIR)/syn/Makefile.dc
include $(BP_COMMON_DIR)/syn/Makefile.regress
include $(BP_COMMON_DIR)/syn/Makefile.verilator
include $(BP_COMMON_DIR)/syn/Makefile.vcs

regress.top: regress
regress: regress.v check_design.syn
	$(MAKE) lint.v || true
	$(MAKE) lint.sc || true

