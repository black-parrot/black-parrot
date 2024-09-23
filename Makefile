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
	git submodule sync --recursive
	git submodule update --init

patch_tag ?= $(addprefix $(BP_RTL_TOUCH_DIR)/patch.,$(shell $(GIT) rev-parse HEAD))
apply_patches: | $(patch_tag)
$(patch_tag):
	$(MAKE) checkout
	git submodule update --init --recursive --recommend-shallow
	touch $@
	@echo "Patching successful, ignore errors"

libs_lite: apply_patches
	$(MAKE) dramsim3

libs: libs_lite

libs_bsg: libs
	$(MAKE) $(BSG_CADENV_DIR)

## This target just wipes the whole repo clean.
#  Use with caution.
bleach_all:
	cd $(TOP); git clean -fdx; git submodule deinit -f .

