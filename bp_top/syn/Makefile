## Top level source directory should include 
# bp_top, bp_fe, bp_be, bp_me, bp_common, bsg_ip_cores, verilator, systemc
TOP              = $(CURDIR)/../..
BP_TOP_DIR	     = $(TOP)/bp_top
BP_FE_DIR	     = $(TOP)/bp_fe
BP_BE_DIR	     = $(TOP)/bp_be
BP_ME_DIR 	     = $(TOP)/bp_me
BP_COMMON_DIR   = $(TOP)/bp_common

CADENV_PATH      = $(TOP)/bsg_cadenv
BSG_IP_CORES_DIR       = $(TOP)/bsg_ip_cores

SRC_PATH	= $(BP_TOP_DIR)/src/v
TB_PATH		= $(BP_TOP_DIR)/test/tb
SYN_PATH	= $(BP_TOP_DIR)/syn

clean:
	rm -rf $(SYN_PATH)/obj_dir
	rm -rf csrc
	rm -rf ucli.key
	rm -rf inter.vpd
	rm -rf DVEfiles
	rm -rf *vpd
	rm -rf *simv
	rm -rf *simv.daidir

#include	$(SYN_PATH)/Makefile.verilator

include $(SYN_PATH)/Makefile.vcs

