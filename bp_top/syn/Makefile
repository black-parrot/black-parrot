## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

SYN_PATH    := $(BP_TOP_DIR)/syn
TB_PATH     := $(BP_TOP_DIR)/test/tb
MEM_PATH    := $(BP_COMMON_DIR)/test/mem
LOG_PATH    := $(BP_TOP_DIR)/syn/logs
REPORT_PATH := $(BP_TOP_DIR)/syn/reports
RUN_PATH    := $(BP_TOP_DIR)/syn/run

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

COH_PROTO ?= mesi
ifeq ($(COH_PROTO), mesi)
  CCE_ROM=$(BP_ME_DIR)/src/v/roms/mesi-tr/bp_cce_inst_rom_mesi-tr_lce$(NUM_LCE_P)_wg$(N_WG)_assoc8.v
else ifeq ($(COH_PROTO), msi)
  CCE_ROM=$(BP_ME_DIR)/src/v/roms/msi-tr/bp_cce_inst_rom_msi-tr_lce$(NUM_LCE_P)_wg$(N_WG)_assoc8.v
else ifeq ($(COH_PROTO), ei)
  CCE_ROM=$(BP_ME_DIR)/src/v/roms/ei-tr/bp_cce_inst_rom_ei-tr_lce$(NUM_LCE_P)_wg$(N_WG)_assoc8.v
endif

ccerom.v:
	@echo $(CCE_ROM)
	@echo $(CCE_ROM) >> $(VCS_RUN_DIR)/flist.vcs || true

ccerom.sc:
	@echo $(CCE_ROM)
	@echo $(CCE_ROM) >> $(VERILATOR_RUN_DIR)/flist.verilator || true


lint.v: ccerom.v
lint.sc: ccerom.sc

build.v: ccerom.v
build.sc: ccerom.sc

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

