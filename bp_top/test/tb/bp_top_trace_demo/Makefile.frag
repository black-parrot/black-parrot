TRACE_REPLAY ?= 1

CCE_TRACE_P ?= 0

DUT_PARAMS = -pvalue+trace_p=$(TRACE_REPLAY)         \
             -pvalue+cce_trace_p=$(CCE_TRACE_P)

TB_PARAMS  = -pvalue+trace_ring_width_p=129          \
             -pvalue+trace_rom_addr_width_p=32

HDL_PARAMS  = $(DUT_PARAMS) $(TB_PARAMS)

