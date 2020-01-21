CCE_TRACE_P    ?= 0
CALC_TRACE_P   ?= 0
CMT_TRACE_P    ?= 0
DRAM_TRACE_P   ?= 0
DCACHE_TRACE_P ?= 0
NPC_TRACE_P    ?= 0
VM_TRACE_P     ?= 0
PRELOAD_MEM_P  ?= 1
LOAD_NBF_P     ?= 0

export DUT_PARAMS = 

export TB_PARAMS  = -pvalue+calc_trace_p=$(CALC_TRACE_P) \
                    -pvalue+cce_trace_p=$(CCE_TRACE_P)   \
                    -pvalue+cmt_trace_p=$(CMT_TRACE_P)   \
                    -pvalue+dram_trace_p=$(DRAM_TRACE_P) \
                    -pvalue+dcache_trace_p=$(DCACHE_TRACE_P) \
                    -pvalue+npc_trace_p=$(NPC_TRACE_P) \
                    -pvalue+vm_trace_p=$(VM_TRACE_P) \
                    -pvalue+preload_mem_p=$(PRELOAD_MEM_P) \
                    -pvalue+load_nbf_p=$(LOAD_NBF_P)

HDL_PARAMS  = $(DUT_PARAMS) $(TB_PARAMS)

