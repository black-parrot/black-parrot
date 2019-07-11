AXE_TRACE_P ?= 0
CCE_TRACE_P  ?= 0
SKIP_INIT_P ?= 0
LCE_PERF_TRACE_P ?= 0

DUT_PARAMS = -pvalue+axe_trace_p=$(AXE_TRACE_P) \
             -pvalue+cce_trace_p=$(CCE_TRACE_P) \
             -pvalue+instr_count=$(NUM_INSTR_P) \
             -pvalue+skip_init_p=$(SKIP_INIT_P) \
             -pvalue+lce_perf_trace_p=$(LCE_PERF_TRACE_P)

TB_PARAMS  = 

HDL_PARAMS  = $(DUT_PARAMS) $(TB_PARAMS)

