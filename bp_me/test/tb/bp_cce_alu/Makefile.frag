TB_PARAMS= -pvalue+width_p=16

HDL_DEFINES=+define+BSG_CORE_CLOCK_PERIOD=10

HDL_PARAMS=$(DUT_PARAMS) $(TB_PARAMS) $(HDL_DEFINES)

TOP_MODULE=bp_cce_alu

CPPFLAGS += -I$(BP_ME_DIR)/test/include -I$(BP_ME_DIR)/src/include/c
