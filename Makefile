## Find top of git repo
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common
include $(BP_EXTERNAL_DIR)/Makefile.tools

.PHONY: update_submodules tools roms

.DEFAULT: update_submodules

## This target updates submodules needed for building BlackParrot.
#  We only need to keep update bsg_ip_cores up to date. The other submodules
#    are for building tools, which we should only need to do every so often

update_submodules:
	cd $(TOP) && git submodule update --init --recursive -- $(BSG_IP_CORES_DIR)

## This target fetches and builds all dependencies needed for running simulations
#    to test BlackParrot. By default, all tools are built but comment any tools that 
#    you already have a copy of. If your version of a tool significantly differs from 
#    our submodule version, use at your own risk.
#  Submodules are deinit-ed after successful build to save space
#  NOTE: spike is a forked version which includes support for generating traces
#          for use in our trace-replay testing infrastructure
#

tools:
	cd $(TOP) && git submodule update --init --recursive
	$(MAKE) verilator systemc && rm -rf systemc*
	$(MAKE) gnu       && git submodule deinit -f $(BP_EXTERNAL_DIR)/riscv-gnu-toolchain
	$(MAKE) fesvr     && git submodule deinit -f $(BP_EXTERNAL_DIR)/riscv-fesvr
	$(MAKE) spike     && git submodule deinit -f $(BP_EXTERNAL_DIR)/riscv-isa-sim
	$(MAKE) axe       && git submodule deinit -f $(BP_EXTERNAL_DIR)/axe
	$(MAKE) dramsim2  && git submodule deinit -f $(BP_EXTERNAL_DIR)/DRAMSim2

## This target makes all of the test roms needed to test BlackParrot with trace-replay
#  NOTE: There are many redundant boot roms generated. However, work is in progress to 
#          remove boot rooms entirely and load programs using trace-replay and FSB. Once
#          these efforts are completed, we will only need to generate the trace roms per
#          End.

roms:
	$(MAKE) -C $(BP_FE_DIR)/test/rom     all
	$(MAKE) -C $(BP_BE_DIR)/test/rom     all
	$(MAKE) -C $(BP_ME_DIR)/test/rom     all
	$(MAKE) -C $(BP_TOP_DIR)/test/rom    all

