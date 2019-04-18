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

AXE = axe

.EXPORT_ALL_VARIABLES:

INCDIR = +incdir+$(BP_COMMON_DIR)/src/include
INCDIR += +incdir+$(BP_BE_DIR)/src/include/bp_be_dcache
INCDIR += +incdir+$(BSG_IP_CORES_DIR)/bsg_misc
INCDIR += +incdir+$(BSG_IP_CORES_DIR)/bsg_noc
INCDIR += +incdir+$(BSG_IP_CORES_DIR)/bsg_mem
INCDIR += +incdir+$(BP_ME_DIR)/src/include/v

HIGHLIGHT = grep --color -E '^|Error|Warning|Implicit wire is used|Too few instance port connections|Port connection width mismatch|Width mismatch'

TRACE_AXE = trace.axe
VCS_LOG = vcs.log

# testparam
NUM_INSTR_P ?= 32768
SEED_P ?= 1

# this test uses a single LCE since it checks the values of loads returned
NUM_LCE_P := 1
CFG        = e_bp_half_core_cfg

NUMS = $(shell seq 0 `expr $(NUM_LCE_P) - 1`)
BASE = bsg_trace_rom_
TRACE_ROMS = $(addsuffix .v, $(addprefix $(BASE), $(NUMS)))

CCE_ROM = $(BP_ME_DIR)/src/v/roms/mesi-tr/bp_cce_inst_rom_mesi-tr_lce$(NUM_LCE_P)_wg64_assoc8.v

all: clean sim

bsg_trace_rom_%.tr:
	python bsg_trace_rom.py -n $(NUM_INSTR_P) -s $(SEED_P) > $@

bsg_trace_rom_%.v: bsg_trace_rom_%.tr
	python $(BSG_IP_CORES_DIR)/bsg_mem/bsg_ascii_to_rom.py $< bsg_trace_rom_$* > $@

sim: clean $(TRACE_ROMS)
	@sed "s/BP_CFG_FLOWVAR/$(CFG)/g" testbench.v > testbench_postsed.v
	vcs +v2k -R +lint=all,noSVA-UA,noSVA-NSVU,noVCDE -sverilog -full64 \
		$(INCDIR) -f sv.include $(TRACE_ROMS) $(CCE_ROM)  \
		-debug_pp -timescale=1ps/1ps +vcs+vcdpluson +vcs+vcdplusmemon -l $(VCS_LOG) \
		+vcs+vcdplusautoflushon +define+NUM_LCE_P=$(NUM_LCE_P) \
		+define+NUM_INSTR_P=$(NUM_INSTR_P) | $(HIGHLIGHT)

dve:
	dve -full64 -vpd vcdplus.vpd &

clean:
	rm -rf DVEfiles
	rm -rf csrc
	rm -rf simv.daidir simv.vdb stack.info.*
	rm -f ucli.key vcdplus.vpd simv cm.log *.tar.gz $(VCS_LOG)
	rm -f bsg_trace_rom_*.v bsg_trace_rom_*.tr $(TRACE_AXE)
	rm -f testbench_postsed.v

###################################################################################################
# NOTE: AXE does not work with this test. This test is for single LCE and the trace replay script
# generates a trace that checks all loads and stores for correctness.

#$(TRACE_AXE): $(VCS_LOG)
#	python $(BP_BE_DIR)/test/tb/bp_be_dcache/py/axe_trace_filter.py $(VCS_LOG) > $(TRACE_AXE)

#axe: $(TRACE_AXE)
#	cat $<
#	$(AXE) check TSO $(TRACE_AXE)
