## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)
include $(TOP)/Makefile.common
include $(TOP)/Makefile.env

# Configuration options
TB        ?= bp_tethered
CFG       ?= e_bp_default_cfg
TAG       ?=

include $(TB_PATH)/Makefile.cfgs
include $(TB_PATH)/Makefile.params
include $(TB_PATH)/Makefile.collateral

include $(BP_MK_DIR)/Makefile.dc

