CCE_TRACE_P    ?= 0
DRAM_TRACE_P   ?= 0
ICACHE_TRACE_P ?= 0
PRELOAD_MEM_P  ?= 1

export DUT_PARAMS = 

export TB_PARAMS  = -pvalue+cce_trace_p=$(CCE_TRACE_P)   \
                    -pvalue+dram_trace_p=$(DRAM_TRACE_P) \
                    -pvalue+icache_trace_p=$(ICACHE_TRACE_P) \
                    -pvalue+preload_mem_p=$(PRELOAD_MEM_P) \

HDL_PARAMS  = $(DUT_PARAMS) $(TB_PARAMS)

