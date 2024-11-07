TOP ?= $(shell git rev-parse --show-toplevel)
include $(TOP)/Makefile.common
include $(TOP)/Makefile.env

include $(BP_RTL_MK_DIR)/Makefile.libs

checkout: ## checkout submodules, but not recursively
	@$(MKDIR) -p $(BP_RTL_BIN_DIR) \
		$(BP_RTL_LIB_DIR) \
		$(BP_RTL_INCLUDE_DIR) \
		$(BP_RTL_TOUCH_DIR)
	@$(GIT) fetch --all
	@$(GIT) submodule sync
	@$(GIT) submodule update --init

apply_patches: ## applies patches to submodules
apply_patches: build.patch
$(eval $(call bsg_fn_build_if_new,patch,$(CURDIR),$(BP_RTL_TOUCH_DIR)))
%/.patch_build: checkout
	@$(GIT) submodule sync --recursive
	@$(GIT) submodule update --init --recursive --recommend-shallow
	@$(ECHO) "Patching successful, ignore errors"

libs_lite: ## minimal RTL libraries
libs_lite: apply_patches
	@$(MAKE) build.dramsim3

libs: ## standard RTL libraries
libs: libs_lite
	# Placeholder

libs_bsg: ## addition RTL libraries for BSG users 
libs_bsg: libs
	# Placeholder

