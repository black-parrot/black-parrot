#
#		Makefile
#

TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

ifneq (,$(findstring xor,$(shell hostname)))
  include $(BSG_CADENV_DIR)/cadenv.mk
else
  $(info Not on xor...VCS not supported)
endif

## End specific flags and variables
BP_ME_SRC_PATH       = $(BP_ME_DIR)/src/v
BP_ME_INC_PATH       = $(BP_ME_DIR)/src/include/v
BP_ME_TB_PATH        = $(BP_ME_DIR)/test
BP_ME_TB_COMMON_PATH = $(BP_ME_TB_PATH)/common
BP_ME_SYN_PATH       = $(BP_ME_DIR)/syn
CCE_ROM_PATH         = $(BP_ME_SRC_PATH)/roms
CCE_SRC_PATH         = $(BP_ME_SRC_PATH)/cce
NETWORK_PATH         = $(BP_ME_SRC_PATH)/network

CPPFLAGS += -I$(BP_ME_DIR)/test/include -I$(BP_ME_DIR)/src/include/c
#CPPFLAGS += -DVM_TRACE=1
CPPFLAGS += -O1

OPT_FAST = -O1 -fstrict-aliasing

.EXPORT_ALL_VARIABLES:

TOP_MODULE = testbench

VV ?= $(VERILATOR)

VV_OPTS = --sc
VV_OPTS += -Wno-unoptflat
VV_OPTS += -O1
VV_OPTS += --trace --trace-structs

BUILD_OPTS := --Wno-fatal --Wno-lint --Wno-style --Wno-widthconcat --exe

all: clean run.sc

verilate.sc: clean
	$(VV) $(VV_OPTS) $(BUILD_OPTS) --top-module $(TOP_MODULE) \
		-f $(BP_ME_DIR)/syn/flist.verilator -f flist.verilator \
		$(HDL_PARAMS) test_bp.cpp

build.sc: verilate.sc
	$(MAKE) -C obj_dir -f V$(TOP_MODULE).mk

run.sc: build.sc
	./obj_dir/V$(TOP_MODULE) > simout.txt

clean:
	rm -rf obj_dir
	rm -f dump.vcd
	rm -f simout.txt

