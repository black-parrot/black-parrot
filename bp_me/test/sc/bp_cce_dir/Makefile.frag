HDL_SOURCE = \
	$(BP_COMMON_PATH)/src/include/bp_common_pkg.vh \
	$(BP_ME_INC_PATH)/bp_cce_pkg.v \
	$(BSG_IP_PATH)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit.v \
	$(BSG_IP_PATH)/bsg_mem/bsg_mem_1rw_sync_mask_write_bit_synth.v \
	$(CCE_SRC_PATH)/bp_cce_dir.v

HDL_PARAMS=-pvalue+num_way_groups_p=64 -pvalue+num_lce_p=1 -pvalue+lce_assoc_p=8 -pvalue+tag_width_p=10
