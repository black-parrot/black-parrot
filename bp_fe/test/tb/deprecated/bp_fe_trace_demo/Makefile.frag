DUT_PARAMS= \

TB_PARAMS= \
           "-pvalue+bp_first_pc_p=32\'h80000124"  \
           -pvalue+boot_rom_width_p=512           \
           -pvalue+boot_rom_els_p=512             \
           -pvalue+trace_ring_width_p=96          \
           -pvalue+mem_els_p=512                  \
           -pvalue+trace_rom_addr_width_p=32

HDL_DEFINES = +define+BSG_CORE_CLOCK_PERIOD=10

HDL_PARAMS = $(DUT_PARAMS) $(TB_PARAMS) $(HDL_DEFINES)

