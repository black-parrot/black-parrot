#
# Makefile
#

TOP ?= $(shell git rev-parse --show-toplevel)

include $(TOP)/Makefile.common

.EXPORT_ALL_VARIABLES:

HIGHLIGHT = grep --color -E '^|Error|Warning|Implicit wire is used|Too few instance port connections|Port connection width mismatch|Width mismatch'

VCS_LOG = vcs.log

# testparam
SEED_P ?= 1
CCE_TRACE_P ?= 0
AXE_TRACE_P ?= 0
DRAMSIM2_P ?= 0
NUM_INSTR_P ?= 8
NUM_LCE_P := 1
CFG=e_bp_half_core_cfg
N_WG := 64

NUMS = $(shell seq 0 `expr $(NUM_LCE_P) - 1`)
BASE = bsg_trace_rom_
TRACE_ROMS = $(addsuffix .v, $(addprefix $(BASE), $(NUMS)))

CFG_INIT_P ?= 0

COH_PROTO ?= mesi
CCE_MEM = $(BP_ME_DIR)/src/asm/roms/$(COH_PROTO)-tr/bp_cce_inst_rom_$(COH_PROTO)-tr_lce$(NUM_LCE_P)_wg$(N_WG)_assoc8.mem

all: clean sim

bsg_trace_rom_%.tr:
	python bsg_trace_rom.py > $@

#python bsg_trace_rom_normal.py -n $(NUM_INSTR_P) -s $(SEED_P) > $@

bsg_trace_rom_%.v: bsg_trace_rom_%.tr
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $< bsg_trace_rom_$* > $@

sim: clean $(TRACE_ROMS)
	@sed "s/BP_CFG_FLOWVAR/$(CFG)/g" testbench.v > testbench_postsed.v
	@cp $(CCE_MEM) cce_ucode.mem
	vcs +v2k -R +lint=all,noSVA-UA,noSVA-NSVU,noVCDE -sverilog -full64 \
		-CFLAGS "-I$(BP_EXTERNAL_DIR)/include -std=c++11" \
		-LDFLAGS "-L$(BP_EXTERNAL_DIR)/lib -ldramsim -Wl,-rpath=$(BP_EXTERNAL_DIR)/lib" \
		-f sv.include $(TRACE_ROMS) \
		-debug_pp -timescale=1ps/1ps +vcs+vcdpluson +vcs+vcdplusmemon -l $(VCS_LOG) \
		+vcs+vcdplusautoflushon +define+NUM_LCE_P=$(NUM_LCE_P) \
		+define+AXE_TRACE_P=$(AXE_TRACE_P) \
		+define+DRAMSIM2_P=$(DRAMSIM2_P) \
		+define+CFG_INIT_P=$(CFG_INIT_P) \
		+define+CCE_TRACE_P=$(CCE_TRACE_P) | $(HIGHLIGHT)

dve:
	dve -full64 -vpd vcdplus.vpd &

clean:
	rm -rf csrc
	rm -rf simv.daidir simv.vdb stack.info.*
	rm -f ucli.key vcdplus.vpd simv cm.log *.tar.gz $(VCS_LOG)
	rm -f bsg_trace_rom_*.v bsg_trace_rom_*.tr
	rm -f testbench_postsed.v
	rm -f *.h
	rm -rf results
	rm -f *.log

clean-dve:
	rm -rf DVEfiles
