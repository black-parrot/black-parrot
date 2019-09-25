CCE_TRACE_P  ?= 0
CALC_TRACE_P ?= 0
CMT_TRACE_P  ?= 0
DRAM_TRACE_P ?= 0

export DUT_PARAMS = 

export TB_PARAMS  = -pvalue+calc_trace_p=$(CALC_TRACE_P) \
                    -pvalue+cce_trace_p=$(CCE_TRACE_P)   \
                    -pvalue+cmt_trace_p=$(CMT_TRACE_P)   \
                    -pvalue+dram_trace_p=$(DRAM_TRACE_P)

HDL_PARAMS  = $(DUT_PARAMS) $(TB_PARAMS)

