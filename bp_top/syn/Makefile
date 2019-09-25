## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

export SYN_PATH     := $(BP_TOP_DIR)/syn
export TB_PATH      := $(BP_TOP_DIR)/test/tb
export MEM_PATH     := $(BP_COMMON_DIR)/test/mem

export LOG_PATH     := $(BP_TOP_DIR)/syn/logs
export RESULTS_PATH := $(BP_TOP_DIR)/syn/results
export REPORT_PATH  := $(BP_TOP_DIR)/syn/reports

TB          ?= bp_top_trace_demo
CFG         ?= e_bp_single_core_cfg
START_PC 		?= 0x80000000
TOLERANCE   ?= 2

# Select CCE ROM based on CFG and Coherence Protocol
# TODO: is there a more scalable way to do this?
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
else ifeq ($(CFG), e_bp_sexta_core_cfg)
  NUM_LCE_P=32
  N_WG=4
else ifeq ($(CFG), e_bp_quad_core_2d_cfg)
  NUM_LCE_P=8
  N_WG=16
else ifeq ($(CFG), e_bp_oct_core_2d_cfg)
  NUM_LCE_P=16
  N_WG=8
endif


COH_PROTO   ?= mesi
CCE_MEM_PATH = $(BP_ME_DIR)/src/asm/roms/$(COH_PROTO)
CCE_MEM      = bp_cce_inst_rom_$(COH_PROTO)_lce$(NUM_LCE_P)_wg$(N_WG)_assoc8.mem

DRAMSIM_CH_CFG  ?= DDR2_micron_16M_8b_x8_sg3E.ini
DRAMSIM_SYS_CFG ?= system.ini

include $(BP_COMMON_DIR)/syn/Makefile.common
include $(BP_COMMON_DIR)/syn/Makefile.dc
include $(BP_COMMON_DIR)/syn/Makefile.regress
include $(BP_COMMON_DIR)/syn/Makefile.verilator
include $(BP_COMMON_DIR)/syn/Makefile.vcs

regress.top: regress
regress: regress.v check_design.syn
	$(MAKE) lint.v || true
	$(MAKE) lint.sc || true

