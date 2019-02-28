## Setup CAD tools
ifneq (,$(findstring xor,$(shell hostname)))
  include $(BSG_CADENV_DIR)/cadenv.mk
else
  $(info Not on xor...VCS and DC not supported)
endif

SYN_PATH = $(BP_BE_DIR)/syn
TB_PATH  = $(BP_BE_DIR)/test/tb

include $(SYN_PATH)/Makefile.vcs
include $(SYN_PATH)/Makefile.dc
include $(SYN_PATH)/Makefile.verilator


