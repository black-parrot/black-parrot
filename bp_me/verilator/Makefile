## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)
include $(TOP)/Makefile.common
include $(TOP)/Makefile.env

TB        ?= bp_cce
CFG       ?= e_bp_test_multicore_half_cfg
TAG       ?=
SUITE     ?= cce
PROG      ?= set_test
COH_PROTO ?= moesif

# Flags
ASSERT ?= 0
TRACE  ?= 0

include $(TB_PATH)/Makefile.cfgs
include $(TB_PATH)/Makefile.params
include $(TB_PATH)/Makefile.collateral

include $(BP_MK_DIR)/Makefile.verilator

