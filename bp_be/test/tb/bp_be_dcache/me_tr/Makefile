#
#		Makefile
#

BP_DIR = $(abspath ../../../../../)
BP_COMMON_DIR = $(BP_DIR)/bp_common
BP_BE_DIR = $(BP_DIR)/bp_be
BP_ME_DIR = $(BP_DIR)/bp_me
BSG_IP_CORES_DIR = $(BP_DIR)/bsg_ip_cores

.EXPORT_ALL_VARIABLES:

INCDIR = +incdir+$(BP_COMMON_DIR)/src/include
INCDIR += +incdir+$(BP_BE_DIR)/src/include/bp_be_dcache
INCDIR += +incdir+$(BSG_IP_CORES_DIR)/bsg_misc
INCDIR += +incdir+$(BSG_IP_CORES_DIR)/bsg_noc
INCDIR += +incdir+$(BP_ME_DIR)/src/include/v

HIGHLIGHT = grep --color -E '^|Error|Warning|Implicit wire is used|Too few instance port connections|Port connection width mismatch|Width mismatch'

TRACE_AXE = trace.axe
VCS_LOG = vcs.log

# TODO: NUM_LCE fixed at 1 for this test
NUM_LCE_P ?= 1
NUMS = $(shell seq 0 `expr $(NUM_LCE_P) - 1`)
BASE = bsg_trace_rom_
TRACE_ROMS = $(addsuffix .v, $(addprefix $(BASE), $(NUMS)))

CCE_ROM = $(BP_ME_DIR)/src/v/roms/demo-v2/bp_cce_inst_rom_demo-v2_lce1_wg16_assoc8.v

all: sim

bsg_trace_rom_%.tr:
	python bsg_trace_rom.py -n 2048 > $@

bsg_trace_rom_%.v: bsg_trace_rom_%.tr
	python $(BSG_IP_CORES_DIR)/bsg_mem/bsg_ascii_to_rom.py $< bsg_trace_rom_$* > $@

sim: clean $(TRACE_ROMS)
	vcs +v2k -R +lint=all,noSVA-UA,noSVA-NSVU,noVCDE -sverilog -full64 \
		$(INCDIR) -f sv.include $(TRACE_ROMS) $(CCE_ROM)  \
		-debug_pp -timescale=1ps/1ps +vcs+vcdpluson +vcs+vcdplusmemon -l $(VCS_LOG) \
		+vcs+vcdplusautoflushon +define+NUM_LCE_P=$(NUM_LCE_P) | $(HIGHLIGHT)

dve:
	dve -full64 -vpd vcdplus.vpd &

clean:
	rm -rf DVEfiles
	rm -rf csrc
	rm -rf simv.daidir simv.vdb stack.info.*
	rm -f ucli.key vcdplus.vpd simv cm.log *.tar.gz $(VCS_LOG)
	rm -f bsg_trace_rom_*.v bsg_trace_rom_*.tr $(TRACE_AXE)

$(TRACE_AXE): $(VCS_LOG)
	python ../py/axe_trace_filter.py $(VCS_LOG) > $(TRACE_AXE)

axe: $(TRACE_AXE)
	cat $<
	axe check TSO $(TRACE_AXE)
