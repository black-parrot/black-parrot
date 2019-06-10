CCE_TRACE_P ?= 0

TB_PARAMS=-pvalue+cce_trace_p=$(CCE_TRACE_P)

HDL_DEFINES=+define+BSG_CORE_CLOCK_PERIOD=10

HDL_PARAMS=$(DUT_PARAMS) $(TB_PARAMS) $(HDL_DEFINES)

TOP_MODULE=bp_cce_test

COH_PROTO ?= mesi-tr
CCE_MEM_PATH=$(BP_ME_DIR)/src/asm/roms/$(COH_PROTO)
CCE_MEM=bp_cce_inst_rom_$(COH_PROTO)_lce1_wg64_assoc8.mem
