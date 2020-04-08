CCE_TRACE_P    ?= 0
DRAM_TRACE_P   ?= 0
DCACHE_TRACE_P ?= 0
PRELOAD_MEM_P  ?= 0
RANDOM_YUMI_P  ?= 0

export DUT_PARAMS = 

export TB_PARAMS  = -pvalue+cce_trace_p=$(CCE_TRACE_P)   \
                    -pvalue+dram_trace_p=$(DRAM_TRACE_P) \
                    -pvalue+dcache_trace_p=$(DCACHE_TRACE_P) \
                    -pvalue+preload_mem_p=$(PRELOAD_MEM_P) \
										-pvalue+random_yumi_p=$(RANDOM_YUMI_P)

HDL_PARAMS  = $(DUT_PARAMS) $(TB_PARAMS)

