TOP ?= $(shell git rev-parse --show-toplevel)
export BP_TOOLS_DIR ?= $(TOP)/tools
export BP_EXTERNAL_DIR  ?= $(TOP)/external
export BASEJUMP_STL_DIR ?= $(BP_EXTERNAL_DIR)/basejump_stl

.PHONY: bleach_all tools bsg_cadenv help
.DEFAULT: help

include $(BP_TOOLS_DIR)/Makefile.common
include $(BP_TOOLS_DIR)/Makefile.tools

help:
	@echo "usage: make [tools, tools_lite]"

## This is the list of target directories that tools and libraries will be installed into
TARGET_DIRS := $(BP_TOOLS_BIN_DIR) $(BP_TOOLS_LIB_DIR) $(BP_TOOLS_INCLUDE_DIR) $(BP_TOOLS_TOUCH_DIR)
$(TARGET_DIRS):
	mkdir -p $@

tools_lite: | $(TARGET_DIRS)
	$(MAKE) verilator
	$(MAKE) -C $(BASEJUMP_STL_DIR)/bsg_test -f libdramsim3.mk
	cp $(BASEJUMP_STL_DIR)/bsg_test/libdramsim3.so $(BP_TOOLS_LIB_DIR)/libdramsim3.so

## This target makes the tools needed for the BlackParrot RTL
tools: tools_lite
	$(MAKE) bsg_sv2v

bsg_cadenv:
	-cd $(BP_TOOLS_DIR); git clone git@github.com:bespoke-silicon-group/bsg_cadenv.git bsg_cadenv

tidy:
	echo "tools are tidy already"

## This target just wipes the whole repo clean.
#  Use with caution.
bleach_all:
	cd $(BP_TOOLS_DIR); git clean -fdx; git submodule deinit -f .

