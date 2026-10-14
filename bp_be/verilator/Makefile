## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)
include $(TOP)/Makefile.common
include $(TOP)/Makefile.env

# Configuration options
TB        ?= bp_dcache
CFG       ?= e_bp_test_unicore_half_cfg
TAG       ?=
SUITE     ?= dcache
PROG      ?= phase1

# Flags
ASSERT ?= 0
TRACE  ?= 0

include $(TB_PATH)/Makefile.cfgs
include $(TB_PATH)/Makefile.params
include $(TB_PATH)/Makefile.collateral

include $(BP_MK_DIR)/Makefile.verilator

