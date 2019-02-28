TB_PARAMS= -pvalue+trace_ring_width_p=124              \
           -pvalue+trace_rom_addr_width_p=32           \
           -pvalue+core_els_p=1                        \
           -pvalue+vaddr_width_p=39                    \
           -pvalue+addr_width_p=56                     \
           -pvalue+asid_width_p=10                     \
           -pvalue+branch_metadata_fwd_width_p=36

DUT_PARAMS=-pvalue+num_cce_p=1                         \
           -pvalue+num_lce_p=2                         \
           -pvalue+mem_els_p=512                       \
           -pvalue+paddr_width_p=56                    \
           -pvalue+lce_sets_p=64                       \
           -pvalue+block_size_in_bytes_p=64            \
           -pvalue+num_inst_ram_els_p=256              \
           -pvalue+lce_assoc_p=8                       \
           -pvalue+boot_rom_els_p=512                  \
           -pvalue+boot_rom_width_p=512                

HDL_DEFINES=+define+BSG_CORE_CLOCK_PERIOD=10

HDL_PARAMS=$(DUT_PARAMS) $(TB_PARAMS) $(HDL_DEFINES)

TOP_MODULE=testbench

