CCE_TRACE_P    ?= 0
CALC_TRACE_P   ?= 0
CMT_TRACE_P    ?= 0
DRAM_TRACE_P   ?= 0
ICACHE_TRACE_P ?= 0
DCACHE_TRACE_P ?= 0
NPC_TRACE_P    ?= 0
VM_TRACE_P     ?= 0
CORE_PROFILE_P ?= 0
PRELOAD_MEM_P  ?= 1
LOAD_NBF_P     ?= 0
COSIM_P        ?= 0
COSIM_INSTR_P  ?= 0
USE_DRAMSIM2_LATENCY_P ?= 0
USE_MAX_LATENCY_P      ?= 1
USE_RANDOM_LATENCY_P   ?= 0

export DUT_PARAMS = 

export TB_PARAMS  = -pvalue+calc_trace_p=$(CALC_TRACE_P) \
                    -pvalue+cce_trace_p=$(CCE_TRACE_P)   \
                    -pvalue+cmt_trace_p=$(CMT_TRACE_P)   \
                    -pvalue+dram_trace_p=$(DRAM_TRACE_P) \
										-pvalue+icache_trace_p=$(ICACHE_TRACE_P) \
                    -pvalue+dcache_trace_p=$(DCACHE_TRACE_P) \
                    -pvalue+npc_trace_p=$(NPC_TRACE_P) \
                    -pvalue+vm_trace_p=$(VM_TRACE_P) \
                    -pvalue+core_profile_p=$(CORE_PROFILE_P) \
                    -pvalue+preload_mem_p=$(PRELOAD_MEM_P) \
                    -pvalue+load_nbf_p=$(LOAD_NBF_P) \
                    -pvalue+cosim_p=$(COSIM_P) \
                    -pvalue+cosim_instr_p=$(COSIM_INSTR_P) \
					-pvalue+use_dramsim2_latency_p=$(USE_DRAMSIM2_LATENCY_P) \
					-pvalue+use_max_latency_p=$(USE_MAX_LATENCY_P) \
					-pvalue+use_random_latency_p=$(USE_RANDOM_LATENCY_P)

BP_SIM_CLK_PERIOD ?= 10

export DUT_DEFINES = 

export TB_DEFINES = +define+BP_SIM_CLK_PERIOD=$(BP_SIM_CLK_PERIOD)

HDL_DEFINES = $(DUT_DEFINES) $(TB_DEFINES)

HDL_PARAMS  = $(DUT_PARAMS) $(TB_PARAMS)

