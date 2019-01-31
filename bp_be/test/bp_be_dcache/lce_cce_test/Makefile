#
#		Makefile
#

INCDIR = +incdir+$(BP_COMMON_DIR)/
INCDIR += +incdir+$(BP_BE_DIR)/bp_dcache/include
INCDIR += +incdir+$(BSG_IP_CORES_DIR)/bsg_misc
INCDIR += +incdir+$(BP_ME_DIR)/include/v

HIGHLIGHT = grep --color -E '^|Error|Warning|Implicit wire is used|Too few instance port connections|Port connection width mismatch|Width mismatch'

TRACE_ROM_0 = bsg_trace_rom_0
TRACE_AXE = trace.axe
VCS_LOG = vcs.log

all: sim

$(TRACE_ROM_0).tr: $(TRACE_ROM_0).py
	python $< > $@

$(TRACE_ROM_0).v: $(TRACE_ROM_0).tr
	python $(BSG_IP_CORES_DIR)/bsg_mem/bsg_ascii_to_rom.py $< $(TRACE_ROM_0) > $@

sim: $(TRACE_ROM_0).v
	vcs +v2k -R +lint=all -sverilog -full64 -f sv.include $(INCDIR) \
		-debug_pp -timescale=1ps/1ps +vcs+vcdpluson +vcs+vcdplusmemon -l $(VCS_LOG) \
		+vcs+vcdplusautoflushon | $(HIGHLIGHT)

dve:
	dve -full64 -vpd vcdplus.vpd &

clean:
	rm -rf DVEfiles
	rm -rf csrc
	rm -rf simv.daidir simv.vdb
	rm -f ucli.key vcdplus.vpd simv cm.log *.tar.gz $(VCS_LOG)
	rm -f $(TRACE_ROM_0).tr $(TRACE_ROM_0).v $(TRACE_AXE)

$(TRACE_AXE): $(VCS_LOG)
	python ../py/axe_trace_filter.py $(VCS_LOG) > $(TRACE_AXE)

axe: $(TRACE_AXE)
	axe check TSO $(TRACE_AXE)
