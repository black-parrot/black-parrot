## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

SYN_PATH    := $(BP_ME_DIR)/syn
TB_PATH     := $(BP_ME_DIR)/test/tb
LOG_PATH    := $(BP_ME_DIR)/syn/logs
REPORT_PATH := $(BP_ME_DIR)/syn/reports

# Default ROM to example
DESIGN_NAME ?= bp_me_top
TB          ?= bp_me_trace_demo

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

regress: regress.me
regress.me: 
	$(MAKE) lint.v || true
	$(MAKE) lint.sc || true
	$(MAKE) run.sc TB=bp_cce_alu
	@grep "PASSED" $(LOG_PATH)/verilator/bp_cce_alu_bp_example_rom_sim.log \
	&& echo "bp_cce_alu: OK" >> $(LOG_PATH)/me_regress.log \
	|| echo "bp_cce_alu: FAIL" >> $(LOG_PATH)/me_regress.log
	$(MAKE) run.sc TB=bp_cce_dir
	@grep "PASSED" $(LOG_PATH)/verilator/bp_cce_dir_bp_example_rom_sim.log \
	&& echo "bp_cce_dir: OK" >> $(LOG_PATH)/me_regress.log \
	|| echo "bp_cce_dir: FAIL" >> $(LOG_PATH)/me_regress.log
	$(MAKE) run.sc TB=bp_cce_gad
	@grep "PASSED" $(LOG_PATH)/verilator/bp_cce_gad_bp_example_rom_sim.log \
	&& echo "bp_cce_gad: OK" >> $(LOG_PATH)/me_regress.log \
	|| echo "bp_cce_gad: FAIL" >> $(LOG_PATH)/me_regress.log
	$(MAKE) run.sc TB=bp_me_top_test
	@grep "PASSED" $(LOG_PATH)/verilator/bp_me_top_test_bp_example_rom_sim.log \
	&& echo "bp_me_top_test: OK" >> $(LOG_PATH)/me_regress.log \
	|| echo "bp_me_top_test: FAIL" >> $(LOG_PATH)/me_regress.log
	$(MAKE) run.sc TB=bp_cce_test
	@grep "PASSED" $(LOG_PATH)/verilator/bp_cce_test_bp_example_rom_sim.log \
	&& echo "bp_cce_test: OK" >> $(LOG_PATH)/me_regress.log \
	|| echo "bp_cce_test: FAIL" >> $(LOG_PATH)/me_regress.log
	$(MAKE) -C $(BP_ME_DIR)/test/tb/bp_me_random_demo \
	| tee -i $(LOG_PATH)/vcs/bp_me_random_stress_test.log
	@grep "mBPC" $(LOG_PATH)/vcs/bp_me_random_stress_test.log \
	| tee -i $(REPORT_PATH)/vcs/bp_me_random_stress_test.rpt
	@grep "mBPC" $(LOG_PATH)/vcs/bp_me_random_stress_test.log \
	|| echo "FAILED" >> $(REPORT_DIR)/bp_me_random_stress_test.err
	@grep "DONE" $(LOG_PATH)/vcs/bp_me_random_stress_test.log \
	&& echo "bp_me_random_demo: OK" >> $(LOG_PATH)/me_regress.log \
	|| echo "bp_me_random_demo: FAIL" >> $(LOG_PATH)/me_regress.log

