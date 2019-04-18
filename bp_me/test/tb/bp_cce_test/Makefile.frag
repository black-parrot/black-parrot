TB_PARAMS= -pvalue+mem_els_p=512                       \
           -pvalue+boot_rom_els_p=512                  \
           -pvalue+boot_rom_width_p=512								 \
					 -pvalue+num_cce_p=1                         \
           -pvalue+num_lce_p=1                         \
           -pvalue+paddr_width_p=56                    \
           -pvalue+lce_sets_p=64                       \
           -pvalue+block_size_in_bytes_p=64            \
           -pvalue+num_inst_ram_els_p=256              \
           -pvalue+lce_assoc_p=8                       \
					 -pvalue+cfg_link_addr_width_p=16            \
					 -pvalue+cfg_link_data_width_p=32

HDL_DEFINES=+define+BSG_CORE_CLOCK_PERIOD=10

HDL_PARAMS=$(DUT_PARAMS) $(TB_PARAMS) $(HDL_DEFINES)

TOP_MODULE=bp_cce_test
