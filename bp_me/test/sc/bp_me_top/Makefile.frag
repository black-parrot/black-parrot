HDL_SOURCE += \
	bp_mem \
	bp_me_top \
	bp_me_mem_rom_0.v \
	bsg_noc_pkg.v \
	bp_coherence_network_channel.v \
	bp_coherence_network.v \
	bsg_mesh_router_buffered.v \
	bsg_mesh_router.v

HDL_PARAMS=-pvalue+num_lce_p=1 -pvalue+num_cce_p=1 -pvalue+num_mem_p=1 \
           -pvalue+addr_width_p=22 -pvalue+lce_assoc_p=8 -pvalue+lce_sets_p=64 \
           -pvalue+block_size_in_bytes_p=64 -pvalue+num_inst_ram_els_p=256 \
					 -pvalue+mem_els_p=512 -pvalue+boot_rom_width_p=512 -pvalue+boot_rom_els_p=512

# use the instruction rom in the rom folder instead of the default
HDL_SOURCE += $(CCE_ROM_PATH)/demo-old/bp_cce_inst_rom_demo_lce1_wg64_assoc8.v
