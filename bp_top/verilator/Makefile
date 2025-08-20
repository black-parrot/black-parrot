## Set common environment variables
TOP ?= $(shell git rev-parse --show-toplevel)
include $(TOP)/Makefile.common
include $(TOP)/Makefile.env

# Configuration options
TB        ?= bp_tethered
CFG       ?= e_bp_default_cfg
TAG       ?=
SUITE     ?=
PROG      ?=
COH_PROTO ?=

# Flags
ASSERT        ?= 0
TRACE         ?= 0
DROMAJO_COSIM ?= 0
SPIKE_COSIM   ?= 0
DISASSEMBLE   ?= 0
COMMITLOG     ?= 0

include $(TB_PATH)/Makefile.cfgs
include $(TB_PATH)/Makefile.params
include $(TB_PATH)/Makefile.collateral

include $(BP_MK_DIR)/Makefile.verilator

