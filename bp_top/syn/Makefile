## Top level source directory should include 
TOP              = $(CURDIR)/../..
BP_TOP_DIR       = $(TOP)/bp_top
BP_FE_DIR        = $(TOP)/bp_fe
BP_BE_DIR        = $(TOP)/bp_be
BP_ME_DIR        = $(TOP)/bp_me
BP_COMMON_DIR    = $(TOP)/bp_common

BSG_CADENV_DIR      = $(TOP)/bsg_cadenv
BSG_IP_CORES_DIR = $(TOP)/bsg_ip_cores

SYN_PATH = $(BP_TOP_DIR)/syn
TB_PATH  = $(BP_TOP_DIR)/test/tb

clean:
	rm -rf $(SYN_PATH)/obj_dir
	rm -rf csrc
	rm -rf ucli.key
	rm -rf inter.vpd
	rm -rf DVEfiles
	rm -rf *vpd
	rm -rf *simv
	rm -rf *simv.daidir

include $(SYN_PATH)/Makefile.vcs

include $(SYN_PATH)/Makefile.dc

include $(SYN_PATH)/Makefile.verilator

