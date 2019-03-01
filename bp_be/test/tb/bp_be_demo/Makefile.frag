DUT_PARAMS = -pvalue+core_els_p=1												 \
             -pvalue+vaddr_width_p=22                    \
             -pvalue+paddr_width_p=22                    \
             -pvalue+asid_width_p=10                     \
             -pvalue+branch_metadata_fwd_width_p=36      \
             -pvalue+num_cce_p=1                         \
             -pvalue+num_lce_p=1                         \
             -pvalue+lce_sets_p=64                       \
             -pvalue+cce_block_size_in_bytes_p=64        \
             -pvalue+lce_assoc_p=8                       \

TB_PARAMS =  -pvalue+boot_rom_els_p=512                  \
             -pvalue+boot_rom_width_p=512                \
             -pvalue+cce_num_inst_ram_els_p=256          \
						 -pvalue+mem_els_p=512

HDL_PARAMS = $(DUT_PARAMS) $(TB_PARAMS)

