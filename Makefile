## Find top of git repo
TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common
include $(BP_EXTERNAL_DIR)/Makefile.tools

.NOTPARALLEL:
.PHONY: update_submodules update_tests tools progs ucode
.DEFAULT: update_submodules

## This target updates submodules needed for building BlackParrot.
#  We only need to keep update basejump_stl up to date. The other submodules
#    are for building tools, which we should only need to do every so often

update_libs:
	cd $(TOP); git submodule update --init --recursive $(BP_EXTERNAL_DIR)/basejump_stl

update_tests:
	cd $(TOP); git submodule update --init --recursive $(BP_COMMON_DIR)/test

tidy_tools:
	cd $(TOP); git submodule deinit -f external/

bleach_all:
	cd $(TOP); git clean -fdx; git submodule deinit -f .

## This target fetches and builds all dependencies needed for running simulations
#    to test BlackParrot. By default, all tools are built but comment any tools that 
#    you already have a copy of. If your version of a tool significantly differs from 
#    our submodule version, use at your own risk.
#
tools:
	$(MAKE) gnu
	$(MAKE) systemc
	$(MAKE) verilator
	$(MAKE) fesvr
	$(MAKE) spike
	$(MAKE) dromajo
	$(MAKE) axe
	$(MAKE) dramsim2
	$(MAKE) cmurphi

progs: update_tests
	$(MAKE) -C $(BP_COMMON_DIR)/test all_mem all_dump all_nbf

ucode:
	$(MAKE) -C $(BP_ME_DIR)/src/asm roms

libs: update_libs

