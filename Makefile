TOP ?= $(shell git rev-parse --show-toplevel)

.PHONY: bleach_all libs tools sdk hdk prep prep_bsg sdk_checkout hdk_checkout checkout

include $(TOP)/Makefile.common

libs:
	cd $(TOP); git submodule update --init --recursive --checkout $(SHALLOW_SUB) $(BASEJUMP_STL_DIR)
	cd $(TOP); git submodule update --init --recursive --checkout $(SHALLOW_SUB) $(HARDFLOAT_DIR)

sdk_checkout:
	cd $(TOP); git submodule update --init --checkout $(SHALLOW_SUB) $(BP_SDK_DIR)
	$(MAKE) -C $(BP_SDK_DIR) checkout

hdk_checkout:
	cd $(TOP); git submodule update --init --checkout $(SHALLOW_SUB) $(BP_HDK_DIR)

checkout:
	$(MAKE) libs
	$(MAKE) sdk_checkout
	$(MAKE) hdk_checkout

tools_lite: libs
	$(MAKE) -C $(BP_TOOLS_DIR) tools_lite

tools: libs
	$(MAKE) -C $(BP_TOOLS_DIR) tools

sdk: tools
	$(MAKE) sdk_checkout
	$(MAKE) -C $(BP_SDK_DIR) sdk

hdk: sdk
	$(MAKE) hdk_checkout
	$(MAKE) -C $(BP_HDK_DIR) hdk

prep: hdk

prep_bsg: prep
	$(MAKE) bsg_cadenv
	$(MAKE) -C $(BP_TOOLS_DIR) bsg_cadenv
	$(MAKE) -C $(BP_SDK_DIR) bsg_cadenv
	$(MAKE) -C $(BP_HDK_DIR) bsg_cadenv

prep_lite: tools_lite
	$(MAKE) sdk_checkout
	$(MAKE) hdk_checkout
	$(MAKE) -C $(BP_SDK_DIR) sdk_lite

bsg_cadenv:
	-cd $(TOP); git clone git@github.com:bespoke-silicon-group/bsg_cadenv.git external/bsg_cadenv

tidy:
	$(MAKE) -C $(BP_TOOLS_DIR) tidy
	$(MAKE) -C $(BP_SDK_DIR) tidy
	$(MAKE) -C $(BP_HDK_DIR) tidy

## This target just wipes the whole repo clean.
#  Use with caution.
bleach_all:
	cd $(TOP); git clean -fdx; git submodule deinit -f .

