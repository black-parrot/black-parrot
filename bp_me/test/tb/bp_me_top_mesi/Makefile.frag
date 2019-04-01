
TB_PARAMS=

DUT_PARAMS = \
             -pvalue+num_lce_p=1 \
             -pvalue+num_cce_p=1 \
             -pvalue+paddr_width_p=22 \
             -pvalue+lce_assoc_p=8 \
             -pvalue+lce_sets_p=64 \
             -pvalue+block_size_in_bytes_p=64 \
             -pvalue+num_inst_ram_els_p=256   \

HDL_PARAMS = $(DUT_PARAMS) $(TB_PARAMS)

TOP_MODULE = bp_me_top

