HDL_SOURCE += \
	$(BP_ME_TB_COMMON_PATH)/bp_mem.v \
	$(BP_ME_TB_COMMON_PATH)/bp_cce_test.v

HDL_PARAMS=-pvalue+num_lce_p=1 -pvalue+num_cce_p=1 \
           -pvalue+addr_width_p=22 -pvalue+lce_assoc_p=8 -pvalue+lce_sets_p=64 \
           -pvalue+block_size_in_bytes_p=64 -pvalue+num_inst_ram_els_p=256

# use the instruction rom in the rom folder instead of the default
#HDL_SOURCE += $(CCE_ROM_PATH)/demo-old/bp_cce_inst_rom_demo_lce1_wg64_assoc8.v
HDL_SOURCE += $(CCE_ROM_PATH)/demo-v2/bp_cce_inst_rom_demo-v2_lce1_wg64_assoc8.v
