## Top level source directory should include 
# bp_top, bp_fe, bp_be, bp_me, bp_common, bsg_ip_cores, verilator, systemc
TOP            = $(abspath $(CURDIR)/../..)
BP_TOP_PATH	   = $(TOP)/bp_top
BP_FE_PATH	   = $(TOP)/bp_fe
BP_BE_PATH	   = $(TOP)/bp_be
BP_ME_PATH 	   = $(TOP)/bp_me
BP_COMMON_PATH = $(TOP)/bp_common

CADENV_PATH    = $(TOP)/bsg_cadenv
BSG_IP_PATH	   = $(TOP)/bsg_ip_cores
VERILATOR_PATH = $(TOP)/verilator-4.006
SYSTEMC_PATH   = $(TOP)/systemc-2.3.2

SRC_PATH	= $(BP_ME_PATH)/src
INC_PATH  = $(SRC_PATH)/include/v
TB_PATH		= $(BP_ME_PATH)/test
SYN_PATH	= $(BP_ME_PATH)/syn
CCE_ROM_PATH = $(SRC_PATH)/v/roms
CCE_SRC_PATH = $(SRC_PATH)/v/cce
NETWORK_PATH = $(SRC_PATH)/v/network

# All synthesizable sources 
# Nonsynth and test sources are added in tool-specific files
HDL_SOURCE = \
	$(abspath $(wildcard $(CCE_SRC_PATH)/*.v)) \
	$(BP_COMMON_PATH)/bp_common_me_if.vh \
	$(BSG_IP_PATH)/bsg_misc/bsg_decode.v \
	$(BSG_IP_PATH)/bsg_misc/bsg_encode_one_hot.v \
	$(BSG_IP_PATH)/bsg_misc/bsg_defines.v \
	$(BSG_IP_PATH)/bsg_misc/bsg_round_robin_arb.v \
	$(BSG_IP_PATH)/bsg_misc/bsg_mux_one_hot.v \
	$(BSG_IP_PATH)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v \
	$(BSG_IP_PATH)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit_synth.v \
	$(BSG_IP_PATH)/bsg_mem/bsg_mem_1rw_sync.v \
	$(BSG_IP_PATH)/bsg_mem/bsg_mem_1rw_sync_synth.v \
	$(BSG_IP_PATH)/bsg_mem/bsg_mem_1r1w.v \
	$(BSG_IP_PATH)/bsg_mem/bsg_mem_1r1w_synth.v \
	$(BSG_IP_PATH)/bsg_dataflow/bsg_two_fifo.v

# Tests that all BP repos are present
test_env:
		[ -d $(BP_TOP_PATH)    ] && [ -d $(BP_FE_PATH)      ] && \
		[ -d $(BP_BE_PATH)     ] && [ -d $(BP_ME_PATH)      ] && \
		[ -d $(BP_COMMON_PATH)    ] && [ -d $(BSG_IP_PATH)     ] && \
		[ -d $(CADENV_PATH)	   ] && [ -d $(VERILATOR_PATH)  ] && \
		[ -d $(SYSTEMC_PATH)   ] && 							 \
		echo "BP environment correctly set up!"

clean:
	rm -rf $(SYN_PATH)/obj_dir
	rm -rf csrc
	rm -rf ucli.key
	rm -rf inter.vpd
	rm -rf DVEfiles
	rm -rf *vpd
	rm -rf *simv
	rm -rf *simv.daidir

include	$(SYN_PATH)/Makefile.verilator

include $(SYN_PATH)/Makefile.vcs

