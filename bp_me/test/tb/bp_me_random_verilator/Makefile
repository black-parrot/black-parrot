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
CPPFLAGS += -DDUMP=1
CPPFLAGS += -O1

OPT_FAST = -O1 -fstrict-aliasing

.EXPORT_ALL_VARIABLES:

HIGHLIGHT = grep --color -E '^|Error|Warning|Implicit wire is used|Too few instance port connections|Port connection width mismatch|Width mismatch'

# testparam
NUM_INSTR_P ?= 32768
N_WG ?= 16
SEED_P ?= 1

# this test uses a single LCE since it checks the values of loads returned
NUM_LCE_P := 1

NUMS = $(shell seq 0 `expr $(NUM_LCE_P) - 1`)
BASE = bsg_trace_rom_
TRACE_ROMS = $(addsuffix .v, $(addprefix $(BASE), $(NUMS)))

CCE_ROM = $(BP_ME_DIR)/src/v/roms/ei-tr/bp_cce_inst_rom_ei-tr_lce$(NUM_LCE_P)_wg$(N_WG)_assoc8.v

TOP_MODULE = bp_me_random_demo_top

VV ?= $(VERILATOR)

VV_OPTS = --sc
VV_OPTS += -Wno-unoptflat
VV_OPTS += -O1
VV_OPTS += --trace --trace-structs

BUILD_OPTS := --Wno-fatal --Wno-lint --Wno-style --Wno-widthconcat --exe

HDL_PARAMS=\
	-pvalue+num_instr_p=$(NUM_INSTR_P) \
	-pvalue+sets_p=$(N_WG)

all: clean run.sc

bsg_trace_rom_%.tr:
	python bsg_trace_rom.py -n $(NUM_INSTR_P) -s $(SEED_P) --sets $(N_WG) > $@

bsg_trace_rom_%.v: bsg_trace_rom_%.tr
	python $(BSG_IP_CORES_DIR)/bsg_mem/bsg_ascii_to_rom.py $< bsg_trace_rom_$* > $@

verilate.sc: clean $(TRACE_ROMS)
	$(VV) $(VV_OPTS) $(BUILD_OPTS) --top-module $(TOP_MODULE) \
		-f $(BP_ME_DIR)/syn/flist.verilator -f flist.verilator $(CCE_ROM) $(TRACE_ROMS) \
		$(HDL_PARAMS) test_bp.cpp

build.sc: verilate.sc
	$(MAKE) -C obj_dir -f V$(TOP_MODULE).mk

run.sc: build.sc
	./obj_dir/V$(TOP_MODULE) > simout.txt

clean:
	rm -rf obj_dir
	rm -f bsg_trace_rom_*.v bsg_trace_rom_*.tr $(TRACE_AXE)
	rm -f dump.vcd
	rm -f simout.txt

