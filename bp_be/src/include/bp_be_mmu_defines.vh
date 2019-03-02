`ifndef BP_BE_MMU_DEFINES_VH
`define BP_BE_MMU_DEFINES_VH

`define declare_bp_be_mmu_structs(vaddr_width_mp, sets_mp, block_size_in_bytes_mp)                 \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic [vaddr_width_mp-`BSG_SAFE_CLOG2(sets_mp*block_size_in_bytes_mp)-1:0] tag;                \
    logic [`BSG_SAFE_CLOG2(sets_mp)-1:0]                                       index;              \
    logic [`BSG_SAFE_CLOG2(block_size_in_bytes_mp)-1:0]                        offset;             \
  }  bp_be_mmu_vaddr_s;                                                                            \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    bp_be_fu_op_s                      mem_op;                                                     \
    logic [vaddr_width_mp-1:0]         vaddr;                                                      \
    logic [rv64_reg_data_width_gp-1:0] data;                                                       \
  }  bp_be_mmu_cmd_s;                                                                              \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic [rv64_reg_data_width_gp-1:0] data;                                                       \
    bp_be_exception_s                  exception;                                                  \
  }  bp_be_mmu_resp_s;                                                                             \


`define bp_be_vtag_width(vaddr_width_mp, sets_mp, block_size_in_bytes_mp)                          \
  (vaddr_width_mp-`BSG_SAFE_CLOG2(sets_mp*block_size_in_bytes_mp))

`define bp_be_ptag_width(paddr_width_mp, sets_mp, block_size_in_bytes_mp)                          \
  (paddr_width_mp-`BSG_SAFE_CLOG2(sets_mp*block_size_in_bytes_mp))

`define bp_be_mmu_vaddr_width(vaddr_width_p, sets_mp, block_size_in_bytes_mp)                      \
  (`bp_be_vtag_width(vaddr_width_mp, sets_mp, block_size_in_bytes_mp)                              \
   + `BSG_SAFE_CLOG2(sets_mp)                                                                      \
   + `BSG_SAFE_CLOG2(block_size_in_bytes_mp)                                                       \
   )

`define bp_be_mmu_cmd_width(vaddr_width_mp)                                                        \
  (`bp_be_fu_op_width + vaddr_width_mp + rv64_reg_data_width_gp)

`define bp_be_mmu_resp_width                                                                       \
  (rv64_reg_data_width_gp + `bp_be_exception_width)

`endif
