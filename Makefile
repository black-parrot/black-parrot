TOP ?= $(shell git rev-parse --show-toplevel)

.PHONY: help libs tidy bleach_all

include $(TOP)/Makefile.common
include $(TOP)/Makefile.libs

help:
	@echo "usage: make [libs, tidy, bleach_all]"

override TARGET_DIRS := $(BP_RTL_BIN_DIR) $(BP_RTL_LIB_DIR) $(BP_RTL_INCLUDE_DIR) $(BP_RTL_TOUCH_DIR)
$(TARGET_DIRS):
	mkdir -p $@

checkout: | $(TARGET_DIRS)
	git fetch --all
	cd $(BP_RTL_DIR); git submodule update --init --recursive --checkout

libs_lite: checkout

libs: libs_lite
	$(MAKE) dramsim3

tidy:
	echo "BlackParrot RTL is tidy enough"

clean:
	$(MAKE) libs_clean

## This target just wipes the whole repo clean.
#  Use with caution.
bleach_all:
	cd $(TOP); git clean -fdx; git submodule deinit -f .

