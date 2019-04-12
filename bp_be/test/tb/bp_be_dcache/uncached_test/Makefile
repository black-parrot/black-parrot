#
#		Makefile
#

BP_DIR = $(abspath ../../../../../)
BP_COMMON_DIR = $(BP_DIR)/bp_common
BP_ME_DIR = $(BP_DIR)/bp_me
BP_BE_DIR = $(BP_DIR)/bp_be
BASEJUMP_STL_DIR = $(BP_DIR)/basejump_stl
BSG_MANYCORE_DIR ?= $(BP_DIR)/bsg_manycore

.EXPORT_ALL_VARIABLES:

INCDIR = +incdir+$(BP_COMMON_DIR)/src/include
INCDIR += +incdir+$(BP_BE_DIR)/src/include/bp_be_dcache
INCDIR += +incdir+$(BASEJUMP_STL_DIR)/bsg_misc
INCDIR += +incdir+$(BASEJUMP_STL_DIR)/bsg_noc
INCDIR += +incdir+$(BP_ME_DIR)/src/include/v
INCDIR += +incdir+$(BSG_MANYCORE_DIR)/v


TRACE_ROM = bsg_trace_rom_0
TRACE_ROM_TR = bsg_trace_rom_0.tr
TRACE_ROM_V = bsg_trace_rom_0.v
VCS_LOG = vcs.log

HIGHLIGHT = grep --color -E '^|Error|Warning|Implicit wire is used|Too few instance port connections|Port connection width mismatch|Width mismatch'

all: sim

$(TRACE_ROM_TR):
	python bsg_trace_rom.py > $@

$(TRACE_ROM_V): $(TRACE_ROM_TR)
	python $(BASEJUMP_STL_DIR)/bsg_mem/bsg_ascii_to_rom.py $< $(TRACE_ROM) > $@
	

sim: $(TRACE_ROM_V)
	vcs -R +v2k -sverilog -full64 \
		-timescale=1ps/1ps +vcs+vcdpluson -l $(VCS_LOG) \
		+lint=all,noSVA-UA,noSVA-NSVU,noVCDE \
		$(INCDIR) -f sv.include | $(HIGHLIGHT)

dve:
	dve -full64 -vpd vcdplus.vpd &

clean:
	rm -rf DVEfiles
	rm -rf csrc
	rm -rf simv.daidir simv.vdb stack.info.*
	rm -f ucli.key vcdplus.vpd simv cm.log *.tar.gz $(VCS_LOG)
	rm -f $(TRACE_ROM_TR) $(TRACE_ROM_V)

clean_rom:
	rm -f $(TRACE_ROM_TR) $(TRACE_ROM_V)
