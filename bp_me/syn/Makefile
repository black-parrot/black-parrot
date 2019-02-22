## Top level source directory should include 
# bp_top, bp_fe, bp_be, bp_me, bp_common, bsg_ip_cores, verilator, systemc
TOP            = $(abspath $(CURDIR)/../..)
BP_TOP_PATH	   = $(TOP)/bp_top
BP_FE_PATH	   = $(TOP)/bp_fe
BP_BE_PATH	   = $(TOP)/bp_be
BP_ME_PATH 	   = $(TOP)/bp_me
BP_COMMON_PATH = $(TOP)/bp_common

# Needed for other dc check_syn
BP_TOP_DIR	     = $(TOP)/bp_top
BP_FE_DIR	       = $(TOP)/bp_fe
BP_BE_DIR	       = $(TOP)/bp_be
BP_ME_DIR 	     = $(TOP)/bp_me
BP_COMMON_DIR    = $(TOP)/bp_common
BSG_IP_CORES_DIR = $(TOP)/bsg_ip_cores
SYN_PATH         = $(BP_ME_DIR)/syn
TB_PATH          = $(BP_ME_DIR)/test/tb

BSG_CADENV_DIR    = $(TOP)/bsg_cadenv
BSG_IP_PATH	   = $(TOP)/bsg_ip_cores
VERILATOR_PATH = $(TOP)/verilator
SYSTEMC_PATH   = $(TOP)/systemc

BP_ME_SRC_PATH	= $(BP_ME_PATH)/src/v
BP_ME_INC_PATH  = $(BP_ME_PATH)/src/include/v
BP_ME_TB_PATH		= $(BP_ME_PATH)/test
BP_ME_SYN_PATH	= $(BP_ME_PATH)/syn
CCE_ROM_PATH = $(BP_ME_SRC_PATH)/roms
CCE_SRC_PATH = $(BP_ME_SRC_PATH)/cce
NETWORK_PATH = $(BP_ME_SRC_PATH)/network

# All synthesizable sources 
# Nonsynth and test sources are added in tool-specific files
HDL_SOURCE = \
	$(BP_COMMON_PATH)/bp_common_pkg.vh \
	$(BP_ME_INC_PATH)/bp_cce_pkg.v \
	$(BP_ME_INC_PATH)/bp_me_network_pkg.v \
	$(BSG_IP_PATH)/bsg_misc/bsg_defines.v \
	$(BSG_IP_PATH)/bsg_noc/bsg_noc_pkg.v \
	$(BSG_IP_PATH)/bsg_noc/bsg_mesh_router_buffered.v \
	$(BSG_IP_PATH)/bsg_noc/bsg_mesh_router.v \
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
	$(BSG_IP_PATH)/bsg_dataflow/bsg_two_fifo.v \
	$(abspath $(wildcard $(CCE_SRC_PATH)/*.v)) \
	$(abspath $(wildcard $(NETWORK_PATH)/*.v)) \
	$(BP_ME_SRC_PATH)/bp_me_top.v \
	$(CCE_ROM_PATH)/bp_me_mem_rom_0.v

#	$(BP_ME_TB_COMMON_PATH)/bp_mem.v \

# Tests that all BP repos are present
test_env:
		[ -d $(BP_TOP_PATH)    ] && [ -d $(BP_FE_PATH)      ] && \
		[ -d $(BP_BE_PATH)     ] && [ -d $(BP_ME_PATH)      ] && \
		[ -d $(BP_COMMON_PATH)    ] && [ -d $(BSG_IP_PATH)     ] && \
		[ -d $(BSG_CADENV_DIR)	   ] && [ -d $(VERILATOR_PATH)  ] && \
		[ -d $(SYSTEMC_PATH)   ] && 							 \
		echo "BP environment correctly set up!"

clean:
	rm -rf $(BP_ME_SYN_PATH)/obj_dir
	rm -rf csrc
	rm -rf ucli.key
	rm -rf inter.vpd
	rm -rf DVEfiles
	rm -rf *vpd
	rm -rf *simv
	rm -rf *simv.daidir

include	$(BP_ME_SYN_PATH)/Makefile.verilator

include $(BP_ME_SYN_PATH)/Makefile.vcs

include $(BP_ME_SYN_PATH)/Makefile.dc

