TRACE_REPLAY ?= 1

CCE_TRACE_P ?= 0

DUT_PARAMS = -pvalue+trace_p=$(TRACE_REPLAY)         \
             -pvalue+cce_trace_p=$(CCE_TRACE_P)

TB_PARAMS  = 

HDL_PARAMS  = $(DUT_PARAMS) $(TB_PARAMS)

