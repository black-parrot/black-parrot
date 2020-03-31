AXE_TRACE_P ?= 0
CCE_TRACE_P ?= 0
LCE_TRACE_P ?= 0
DRAM_TRACE_P ?= 0

DUT_PARAMS = -pvalue+axe_trace_p=$(AXE_TRACE_P) \
             -pvalue+cce_trace_p=$(CCE_TRACE_P) \
             -pvalue+instr_count=$(NUM_INSTR_P) \
             -pvalue+skip_init_p=$(SKIP_INIT_P) \
             -pvalue+lce_trace_p=$(LCE_TRACE_P) \
             -pvalue+dram_trace_p=$(DRAM_TRACE_P) \

TB_PARAMS  = 

HDL_PARAMS  = $(DUT_PARAMS) $(TB_PARAMS)

