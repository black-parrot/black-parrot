TRACE_REPLAY ?= 1

DUT_PARAMS = -pvalue+trace_p=$(TRACE_REPLAY)

TB_PARAMS  = -pvalue+trace_ring_width_p=129          \
             -pvalue+trace_rom_addr_width_p=32       \
             -pvalue+mem_els_p=1024

HDL_PARAMS  = $(DUT_PARAMS) $(TB_PARAMS)

