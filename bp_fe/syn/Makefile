## Top level source directory should include 
# bp_top, bp_fe, bp_be, bp_me, bp_common, bsg_ip_cores, verilator, systemc
TOP            = $(CURDIR)/../..
BP_TOP_PATH    = $(TOP)/bp_top
BP_FE_PATH     = $(TOP)/bp_fe
BP_BE_PATH     = $(TOP)/bp_be
BP_ME_PATH     = $(TOP)/bp_me
BP_COMMON_PATH = $(TOP)/bp_common


BSG_CADENV_DIR    = $(TOP)/bsg_cadenv
BSG_IP_PATH    = $(TOP)/bsg_ip_cores
VERILATOR_PATH = $(TOP)/verilator
SYSTEMC_PATH   = $(TOP)/systemc

SRC_PATH  = $(BP_FE_PATH)/src/v
TB_PATH   = $(BP_FE_PATH)/test/tb
SYN_PATH  = $(BP_FE_PATH)/syn
INC_PATH  = $(BP_FE_PATH)/src/include

VTB_PATH  = $(TB_PATH)/v
SCTB_PATH = $(TB_PATH)/sc

BP_TOP_DIR       = $(TOP)/bp_top
BP_FE_DIR        = $(TOP)/bp_fe
BP_BE_DIR        = $(TOP)/bp_be
BP_ME_DIR        = $(TOP)/bp_me
BP_COMMON_DIR    = $(TOP)/bp_common
BSG_IP_CORES_DIR = $(TOP)/bsg_ip_cores

include $(SYN_PATH)/Makefile.vcs

include $(SYN_PATH)/Makefile.dc

include $(SYN_PATH)/Makefile.verilator

