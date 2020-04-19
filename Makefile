## Find top of git repo
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

BP_BIN_DIR     := $(BP_EXTERNAL_DIR)/bin
BP_LIB_DIR     := $(BP_EXTERNAL_DIR)/lib
BP_INCLUDE_DIR := $(BP_EXTERNAL_DIR)/include
BP_TOUCH_DIR   := $(BP_EXTERNAL_DIR)/touchfiles

include $(BP_EXTERNAL_DIR)/Makefile.tools

.DEFAULT: prep

## This is a small target which runs fast and allows folks to run hello world
prep_lite: | $(TARGET_DIRS)
	git submodule update --init
	$(MAKE) libs
	$(MAKE) verilator
	$(MAKE) -j1 ucode

## This is the big target that just builds everything. Most users should just press this button
prep: | $(TARGET_DIRS)
	git submodule update --init
	$(MAKE) libs
	$(MAKE) tools
	$(MAKE) -j1 progs 
	$(MAKE) -j1 ucode

## This target updates submodules needed for building BlackParrot.
#  We only need to keep update basejump_stl up to date. The other submodules
#    are for building tools, which we should only need to do every so often

tidy_tools:
	cd $(TOP); git submodule deinit -f external/riscv-gnu-toolchain
	cd $(TOP); git submodule deinit -f external/verilator
	cd $(TOP); git submodule deinit -f external/dromajo
	cd $(TOP); git submodule deinit -f external/riscv-isa-sim
	cd $(TOP); git submodule deinit -f external/axe
	cd $(TOP); git submodule deinit -f external/cmurphi
	cd $(TOP); git submodule deinit -f external/sv2v


## This target just wipes the whole repo clean.
#  Use with caution.
bleach_all:
	cd $(TOP); git clean -fdx; git submodule deinit -f .

## This is the list of target directories that tools and libraries will be installed into
TARGET_DIRS := $(BP_BIN_DIR) $(BP_LIB_DIR) $(BP_INCLUDE_DIR) $(BP_TOUCH_DIR)
$(TARGET_DIRS):
	mkdir $@

## These targets fetch and build all dependencies needed for running simulations
#    to test BlackParrot. By default, all tools are built but comment any tools that 
#    you already have a copy of. If your version of a tool significantly differs from 
#    our submodule version, use at your own risk. 
#
libs: $(TARGET_DIRS)
	$(MAKE) basejump
	$(MAKE) dramsim2
	$(MAKE) dramsim3

tools: | $(TARGET_DIRS)
	$(MAKE) gnu
	$(MAKE) verilator
	$(MAKE) dromajo
	$(MAKE) spike
	#$(MAKE) axe
	#$(MAKE) cmurphi
	#$(MAKE) sv2v
	#$(MAKE) bsg_sv2v

progs: tools
	git submodule update --init --recursive $(BP_COMMON_DIR)/test
	$(MAKE) -C $(BP_COMMON_DIR)/test all_mem all_dump all_nbf

ucode: | basejump
	$(MAKE) -C $(BP_ME_DIR)/src/asm roms

rebuild-gcc:
	$(MAKE) -C external/riscv-gnu-toolchain clean
	$(MAKE) -j 8 -C external -f Makefile.tools gnu_build

STALLS=instr dir_mispredict load_dep fe_cmd branch_override ret_override target_mispredict ret_mispredict mul icache dcache long_haz cmd_fence unknown control_haz struct_haz fe_queue_stall fe_wait_stall

stall.%:
	-@printf "%-20s: " $*; printf "%8d\n" `find . -iname "stall_0.trace" | xargs -n 1 grep -c $*`

profile-header:	
	@echo "Coremark score per MHz; divide 5e6 by cycles"
	-@find . -iname "stall_0.trace" | xargs -n 1 grep -v $(foreach x,$(STALLS),-e $(x))
	-@printf "%-20s: " "cycles"; printf "%8d\n" $$(cat `find . -iname "stall_0.trace" | xargs -n 1` | wc -l)

profile: profile-header $(foreach x,$(STALLS),stall.$(x))

profile-branch-mispredicts:
	grep dir_mispredict ./bp_top/syn/results/vcs/bp_softcore.e_bp_single_core_cfg.sim/coremark/stall_0.trace | awk -F, '{print $$4}' | sort | uniq -c

profile-target-mispredict:
	echo "#!/bin/bash" > runit	
	echo grep -B1 `grep target_mispredict ./bp_top/syn/results/vcs/bp_softcore.e_bp_single_core_cfg.sim/coremark/stall_0.trace | awk -F, '{print " -e ",$$4}' | cut --complement -b5-7 | sort | uniq | tr '\n' ':'` bp_common/test/mem/coremark.dump >> runit
	chmod u+x ./runit;	./runit | tee profile-target-mispredicts-list
	# eval "grep -B1 $$CMD  

# note: change coremark compile time parameters in bp_common/test/src/coremark/barebones/Makefile
# dump files are located in bp_com
rebuild-run-coremark:
	$(MAKE) -C bp_common/test coremark_mem coremark_dump coremark_nbf
	@echo BP: Disassembly in "bp_common/test/mem/coremark.dump".
	$(MAKE) -C bp_top/syn build.v TB=bp_softcore CFG=e_bp_softcore_cfg PROG=coremark CORE_PROFILE_P=1
	$(MAKE) -C bp_top/syn sim.v TB=bp_softcore CFG=e_bp_softcore_cfg PROG=coremark CORE_PROFILE_P=1
	$(MAKE) profile

