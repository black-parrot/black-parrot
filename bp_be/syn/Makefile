# Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

SYN_PATH    := $(BP_BE_DIR)/syn
TB_PATH     := $(BP_BE_DIR)/test/tb
LOG_PATH    := $(BP_BE_DIR)/syn/logs
REPORT_PATH := $(BP_BE_DIR)/syn/reports

# Default ROM to example
TB          ?= bp_be_trace_demo
CFG         ?= e_bp_half_core_cfg

.EXPORT_ALL_VARIABLES:

include $(BP_COMMON_DIR)/syn/Makefile.common
include $(BP_COMMON_DIR)/syn/Makefile.dc
include $(BP_COMMON_DIR)/syn/Makefile.regress
include $(BP_COMMON_DIR)/syn/Makefile.verilator
include $(BP_COMMON_DIR)/syn/Makefile.vcs

DCACHE_AXE_TEST_DIR = $(BP_BE_DIR)/test/tb/bp_be_dcache/dcache_axe_test

regress: regress.be
regress.be: check_design.syn
	#$(MAKE) lint.v || true
	#$(MAKE) lint.sc || true
	for lce in 2 4 8 16; do \
		echo "Running $$lce LCE AXE TEST"; \
		$(MAKE) -C $(DCACHE_AXE_TEST_DIR) NUM_LCE_P=$$lce NUM_INSTR_P=2500 \
		| tee $(LOG_PATH)/vcs/dcache_axe_test_$$lce.sim.log; \
		$(MAKE) -C $(DCACHE_AXE_TEST_DIR) axe \
		| tee $(LOG_PATH)/vcs/dcache_axe_test_$$lce.axe.log; \
		grep "OK" $(LOG_PATH)/vcs/dcache_axe_test_$$lce.axe.log \
		&& echo "$$lce test: OK" >> $(REPORT_PATH)/vcs/dcache_axe_test.rpt \
		|| echo "$$lce test: FAIL" >> $(REPORT_PATH)/vcs/dcache_axe_test.rpt; \
		grep "FAIL" $(REPORT_PATH)/vcs/dcache_axe_test.rpt | tee -a $(REPORT_PATH)/vcs/dcache_axe_test.err; \
	done

