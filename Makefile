TOP ?= $(shell git rev-parse --show-toplevel)
include $(TOP)/Makefile.common
include $(TOP)/Makefile.env

include $(BP_MK_DIR)/Makefile.libs

libs_lite: ## minimal RTL libraries
libs_lite:
	@$(MAKE) build.dramsim3
	@$(MAKE) build.bedrock

libs: ## standard RTL libraries
libs: libs_lite
	# Placeholder

libs_bsg: ## addition RTL libraries for BSG users 
libs_bsg: libs
	# Placeholder

