`ifndef BP_BE_MEM_DEFINES_VH
`define BP_BE_MEM_DEFINES_VH

`define declare_bp_be_mmu_structs(vaddr_width_mp, ppn_width_mp, sets_mp, block_size_in_bytes_mp) \
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
    bp_be_mmu_vaddr_s                  vaddr;                                                      \
    logic [rv64_reg_data_width_gp-1:0] data;                                                       \
    logic                              fe_exc_v;                                                   \
    bp_fe_exception_code_e             fe_ecode;                                                   \
  }  bp_be_mmu_cmd_s;                                                                              \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    bp_be_fu_op_s                      csr_op;                                                     \
    logic [rv64_csr_addr_width_gp-1:0] csr_addr;                                                   \
    logic [rv64_reg_data_width_gp-1:0] data;                                                       \
  }  bp_be_csr_cmd_s;                                                                              \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic [rv64_reg_data_width_gp-1:0] data;                                                       \
  }  bp_be_mem_resp_s;                                                                             \

`define declare_bp_be_tlb_entry_s(ppn_width_mp) \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic [ppn_width_mp-1:0]   ptag;                                                               \
    logic                      g;                                                                  \
    logic                      u;                                                                  \
    logic                      x;                                                                  \
    logic                      w;                                                                  \
    logic                      r;                                                                  \
                                                                                                   \
    logic                      uc;                                                                 \
  } bp_be_tlb_entry_s;                                                                             \
                                                                                                   \

`define bp_be_tlb_entry_width(ppn_width_mp)     \
  (ppn_width_mp + 6)                            
  
  typedef struct packed 
  {
    logic [bp_sv39_pte_width_gp-10-bp_sv39_paddr_width_gp-1:0] reserved;
    logic [bp_sv39_paddr_width_gp-1:0] ppn;
    logic [1:0] rsw;
    logic d;
    logic a;
    logic g;
    logic u;
    logic x;
    logic w;
    logic r;
    logic v;
  }  bp_sv39_pte_s;

`define bp_sv39_pte_width ($bits(bp_sv39_pte_s))

`define bp_be_vtag_width(vaddr_width_mp, sets_mp, block_size_in_bytes_mp) \
  (vaddr_width_mp - `BSG_SAFE_CLOG2(sets_mp*block_size_in_bytes_mp))

`define bp_be_ptag_width(paddr_width_mp, sets_mp, block_size_in_bytes_mp) \
  (paddr_width_mp - `BSG_SAFE_CLOG2(sets_mp*block_size_in_bytes_mp))

`define bp_be_mmu_vaddr_width(vaddr_width_p, sets_mp, block_size_in_bytes_mp) \
  (`bp_be_vtag_width(vaddr_width_mp, sets_mp, block_size_in_bytes_mp)                              \
   + `BSG_SAFE_CLOG2(sets_mp)                                                                      \
   + `BSG_SAFE_CLOG2(block_size_in_bytes_mp)                                                       \
   )

`define bp_be_mmu_cmd_width(vaddr_width_mp) \
  (`bp_be_fu_op_width + vaddr_width_mp + rv64_reg_data_width_gp + 1 + $bits(bp_fe_exception_code_e))

`define bp_be_csr_cmd_width \
  (`bp_be_fu_op_width + rv64_csr_addr_width_gp + rv64_reg_data_width_gp)

`define bp_be_mem_resp_width(vaddr_width_mp)                                                                     \
  (rv64_reg_data_width_gp)

`endif

