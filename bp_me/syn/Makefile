## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

SYN_PATH    := $(BP_ME_DIR)/syn
TB_PATH     := $(BP_ME_DIR)/test/tb
LOG_PATH    := $(BP_ME_DIR)/syn/logs
REPORT_PATH := $(BP_ME_DIR)/syn/reports
RESULTS_PATH := $(BP_ME_DIR)/syn/results

# Default ROM to example
TB          ?= bp_me_trace_demo
CFG         ?= e_bp_single_core_cfg

## End specific flags and variables
BP_ME_SRC_PATH       = $(BP_ME_DIR)/src/v
BP_ME_INC_PATH       = $(BP_ME_DIR)/src/include/v
BP_ME_TB_PATH        = $(BP_ME_DIR)/test
BP_ME_TB_COMMON_PATH = $(BP_ME_TB_PATH)/common
BP_ME_SYN_PATH       = $(BP_ME_DIR)/syn
CCE_ROM_PATH         = $(BP_ME_SRC_PATH)/roms
CCE_SRC_PATH         = $(BP_ME_SRC_PATH)/cce
NETWORK_PATH         = $(BP_ME_SRC_PATH)/network

# C includes used by verilator
CPPFLAGS += -I$(BP_ME_TB_PATH)/include -I$(BP_ME_DIR)/src/include/c

.EXPORT_ALL_VARIABLES:

include $(BP_COMMON_DIR)/syn/Makefile.common
include $(BP_COMMON_DIR)/syn/Makefile.dc
include $(BP_COMMON_DIR)/syn/Makefile.regress
include $(BP_COMMON_DIR)/syn/Makefile.verilator
include $(BP_COMMON_DIR)/syn/Makefile.vcs

lint.me:
	# TODO: The linter currently depends on the broken me_trace_tb
	#$(MAKE) lint.v || true
	#$(MAKE) lint.sc || true

regress.me.sc: dirs.sc
	$(MAKE) build.sc TB=bp_cce_alu
	$(MAKE) run.sc TB=bp_cce_alu
	@grep "PASSED" $(LOG_PATH)/verilator/bp_cce_alu_rv64ui-p-simple_sim.log \
	&& echo "bp_cce_alu: OK" >> $(LOG_PATH)/me_regress.log \
	|| echo "bp_cce_alu: FAIL" >> $(LOG_PATH)/me_regress.log
	$(MAKE) build.sc TB=bp_cce_dir
	$(MAKE) run.sc TB=bp_cce_dir
	@grep "PASSED" $(LOG_PATH)/verilator/bp_cce_dir_rv64ui-p-simple_sim.log \
	&& echo "bp_cce_dir: OK" >> $(LOG_PATH)/me_regress.log \
	|| echo "bp_cce_dir: FAIL" >> $(LOG_PATH)/me_regress.log
	$(MAKE) build.sc TB=bp_cce_gad
	$(MAKE) run.sc TB=bp_cce_gad
	@grep "PASSED" $(LOG_PATH)/verilator/bp_cce_gad_rv64ui-p-simple_sim.log \
	&& echo "bp_cce_gad: OK" >> $(LOG_PATH)/me_regress.log \
	|| echo "bp_cce_gad: FAIL" >> $(LOG_PATH)/me_regress.log
	$(MAKE) build.sc TB=bp_cce_test
	$(MAKE) run.sc TB=bp_cce_test
	@grep "PASSED" $(LOG_PATH)/verilator/bp_cce_test_rv64ui-p-simple_sim.log \
	&& echo "bp_cce_test: OK" >> $(LOG_PATH)/me_regress.log \
	|| echo "bp_cce_test: FAIL" >> $(LOG_PATH)/me_regress.log

regress.me.v: dirs.v
	$(MAKE) -C $(BP_ME_DIR)/test/tb/bp_me_mock_lce \
	| tee -i $(LOG_PATH)/vcs/bp_me_mock_lce.log
	@grep "mBPC" $(LOG_PATH)/vcs/bp_me_mock_lce.log \
	| tee -i $(REPORT_PATH)/vcs/bp_me_mock_lce.rpt
	@grep "mBPC" $(LOG_PATH)/vcs/bp_me_mock_lce.log \
	|| echo "FAILED" >> $(REPORT_DIR)/bp_me_mock_lce.err
	@grep "DONE" $(LOG_PATH)/vcs/bp_me_mock_lce.log \
	&& echo "bp_me_mock_lce: OK" >> $(LOG_PATH)/me_regress.log \
	|| echo "bp_me_mock_lce: FAIL" >> $(LOG_PATH)/me_regress.log
	$(MAKE) -C $(BP_ME_DIR)/test/tb/bp_me_mock_lce_uc \
	| tee -i $(LOG_PATH)/vcs/bp_me_mock_lce_uc.log
	@grep "mBPC" $(LOG_PATH)/vcs/bp_me_mock_lce_uc.log \
	| tee -i $(REPORT_PATH)/vcs/bp_me_mock_lce_uc.rpt
	@grep "mBPC" $(LOG_PATH)/vcs/bp_me_mock_lce_uc.log \
	|| echo "FAILED" >> $(REPORT_DIR)/bp_me_mock_lce_uc.err
	@grep "DONE" $(LOG_PATH)/vcs/bp_me_mock_lce_uc.log \
	&& echo "bp_me_mock_lce_uc: OK" >> $(LOG_PATH)/me_regress.log \
	|| echo "bp_me_mock_lce_uc: FAIL" >> $(LOG_PATH)/me_regress.log
	$(MAKE) -C $(BP_ME_DIR)/test/tb/bp_me_mock_lce_tiled NUM_LCE_P=16 AXE_TRACE_P=1 NUM_INSTR_P=4096 \
	| tee -i $(LOG_PATH)/vcs/bp_me_mock_lce_tiled.log
	@grep "mBPC" $(LOG_PATH)/vcs/bp_me_mock_lce_tiled.log \
	| tee -i $(REPORT_PATH)/vcs/bp_me_mock_lce_tiled.rpt
	@grep "mBPC" $(LOG_PATH)/vcs/bp_me_mock_lce_tiled.log \
	|| echo "FAILED" >> $(REPORT_DIR)/bp_me_mock_lce_tiled.err
	@grep "DONE" $(LOG_PATH)/vcs/bp_me_mock_lce_tiled.log \
	&& echo "bp_me_mock_lce_tiled: OK" >> $(LOG_PATH)/me_regress.log \
	|| echo "bp_me_mock_lce_tiled: FAIL" >> $(LOG_PATH)/me_regress.log
	$(MAKE) -C $(BP_ME_DIR)/test/tb/bp_me_mock_lce_tiled axe \
	| tee -i $(LOG_PATH)/vcs/bp_me_mock_lce_tiled_axe.log
	@grep "OK" $(LOG_PATH)/vcs/bp_me_mock_lce_tiled_axe.log \
	&& echo "bp_me_mock_lce_tiled_axe: OK" >> $(LOG_PATH)/me_regress.log \
	|| echo "bp_me_mock_lce_tiled_axe: FAIL" >> $(LOG_PATH)/me_regress.log

regress: regress.me
regress.me: lint.me regress.me.sc regress.me.v check_design.syn

clean: clean.me
clean.me:
	$(MAKE) -C $(BP_ME_DIR)/test/tb/bp_me_mock_lce clean
	$(MAKE) -C $(BP_ME_DIR)/test/tb/bp_me_mock_lce_uc clean
	$(MAKE) -C $(BP_ME_DIR)/test/tb/bp_me_mock_lce_tiled clean

