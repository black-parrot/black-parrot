CCE_TRACE_P    ?= 0
DRAM_TRACE_P   ?= 0
ICACHE_TRACE_P ?= 0
UCE_P          ?= 1

export DUT_PARAMS = 

export TB_PARAMS  = -pvalue+cce_trace_p=$(CCE_TRACE_P)   \
                    -pvalue+dram_trace_p=$(DRAM_TRACE_P) \
                    -pvalue+icache_trace_p=$(ICACHE_TRACE_P) \
                    -pvalue+uce_p=$(UCE_P) \

HDL_PARAMS  = $(DUT_PARAMS) $(TB_PARAMS)

