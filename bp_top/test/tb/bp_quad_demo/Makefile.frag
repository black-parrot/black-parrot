HDL_PARAMS=-pvalue+vaddr_width_p=22 			                           \
		   -pvalue+paddr_width_p=22 			                           \
		   -pvalue+asid_width_p=10 				                           \
		   -pvalue+branch_metadata_fwd_width_p=36                          \
		   -pvalue+core_els_p=4											   \
		   -pvalue+num_cce_p=1					                           \
		   -pvalue+num_lce_p=8					                           \
		   -pvalue+num_mem_p=1											   \
		   -pvalue+coh_states_p=4				                           \
		   -pvalue+lce_sets_p=16										   \
		   -pvalue+cce_block_size_in_bytes_p=64							   \
		   -pvalue+cce_num_inst_ram_els_p=256							   \
		   -pvalue+lce_assoc_p=8				                           \
		   -pvalue+boot_rom_els_p=512									   \
		   -pvalue+boot_rom_width_p=512									   \

HDL_SOURCE += $(BP_ME_DIR)/src/v/roms/demo-v2/bp_cce_inst_rom_demo-v2_lce8_wg16_assoc8.v
