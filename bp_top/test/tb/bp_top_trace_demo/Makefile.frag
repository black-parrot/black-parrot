CCE_TRACE_P  ?= 0
CALC_TRACE_P ?= 0
CALC_PRINT_P ?= 0

DUT_PARAMS = -pvalue+calc_trace_p=$(CALC_TRACE_P) \
             -pvalue+calc_print_p=$(CALC_PRINT_P) \
             -pvalue+cce_trace_p=$(CCE_TRACE_P) \

TB_PARAMS  = 

HDL_PARAMS  = $(DUT_PARAMS) $(TB_PARAMS)

