HDL_SOURCE=bp_common_pkg.vh						\
		   bp_dcache_pkg.vh						\
		   bp_dcache_lce_pkg.vh					\
		   bp_cce_inst_pkg.v					\
		   bsg_noc_pkg.v						\
		   bp_be_nonsynth_mock_fe_top_wrapper.v \
		   bp_cce_inst_rom_lce1.v				
HDL_PARAMS=-pvalue+vaddr_width_p=22 			                           \
		   -pvalue+paddr_width_p=22 			                           \
		   -pvalue+asid_width_p=1 				                           \
		   -pvalue+branch_metadata_fwd_width_p=1                           \
		   -pvalue+num_cce_p=1					                           \
		   -pvalue+num_lce_p=1					                           \
		   -pvalue+num_mem_p=1											   \
		   -pvalue+coh_states_p=4				                           \
		   -pvalue+lce_assoc_p=8				                           \
		   -pvalue+lce_sets_p=64										   \
		   -pvalue+cce_block_size_in_bytes_p=64							   \
		   -pvalue+cce_num_inst_ram_els_p=256							   \
		   -pvalue+boot_rom_els_p=512									   \
		   -pvalue+boot_rom_width_p=512									   \

