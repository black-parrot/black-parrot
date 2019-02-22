HDL_SOURCE = \
	$(BP_COMMON_PATH)/bp_common_pkg.vh \
	$(BP_ME_INC_PATH)/bp_cce_pkg.v \
	$(CCE_SRC_PATH)/bp_cce_gad.v

HDL_PARAMS=-pvalue+num_way_groups_p=4 -pvalue+num_lce_p=4 -pvalue+lce_assoc_p=4 -pvalue+tag_width_p=4
