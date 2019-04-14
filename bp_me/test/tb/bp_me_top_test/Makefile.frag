TB_PARAMS= -pvalue+mem_els_p=512                       \
           -pvalue+boot_rom_els_p=512                  \
           -pvalue+boot_rom_width_p=512

HDL_DEFINES=+define+BSG_CORE_CLOCK_PERIOD=10

HDL_PARAMS=$(DUT_PARAMS) $(TB_PARAMS) $(HDL_DEFINES)

TOP_MODULE=bp_me_top_test

# TODO: lint.sc passes for bp_me_top_test if we ignore width and widthconcat warnings
# this should be removed after fixing things up, but a lot of these errors come from bsg_ip_cores
#LINT_OPTS += -Wno-widthconcat -Wno-width
