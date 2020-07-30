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
	cd $(TOP); git submodule deinit -f external/zachjs_sv2v


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
	$(MAKE) dromajo

tools: | $(TARGET_DIRS)
	$(MAKE) gnu
	$(MAKE) verilator
	$(MAKE) dromajo
	$(MAKE) spike
	#$(MAKE) axe
	#$(MAKE) cmurphi
	#$(MAKE) zachjs_sv2v
	#$(MAKE) bsg_sv2v

progs: tools
	git submodule update --init --recursive $(BP_COMMON_DIR)/test
	$(MAKE) -C $(BP_COMMON_DIR)/test perch bp_tests riscv_tests beebs coremark bootrom

ucode: | basejump
	$(MAKE) -C $(BP_ME_DIR)/src/asm roms

