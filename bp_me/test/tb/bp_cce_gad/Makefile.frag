TB_PARAMS=-pvalue+num_way_groups_p=4 \
					 -pvalue+num_lce_p=4 \
					 -pvalue+lce_assoc_p=4 \
					 -pvalue+tag_width_p=4

HDL_DEFINES=+define+BSG_CORE_CLOCK_PERIOD=10

HDL_PARAMS=$(DUT_PARAMS) $(TB_PARAMS) $(HDL_DEFINES)

TOP_MODULE=bp_cce_gad
