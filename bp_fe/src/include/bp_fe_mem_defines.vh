
`ifndef BP_FE_MEM_DEFINES_VH
`define BP_FE_MEM_DEFINES_VH

typedef enum bit [1:0]
{
  e_fe_op_fetch      = 2'b00
  ,e_fe_op_tlb_fence = 2'b01
  ,e_fe_op_tlb_fill  = 2'b10
} bp_fe_mem_cmd_op_e;

`define declare_bp_fe_mem_structs(vaddr_width_mp, lce_sets_mp, cce_block_width_mp, vtag_width_mp, ptag_width_mp) \
  typedef struct packed                                        \
  {                                                            \
    logic [vtag_width_mp-1:0]                         tag;     \
    logic [`BSG_SAFE_CLOG2(lce_sets_mp)-1:0]          index;   \
    logic [`BSG_SAFE_CLOG2(cce_block_width_mp/8)-1:0] offset;  \
  }  bp_fe_vaddr_s;                                            \
                                                               \
  typedef struct packed                                        \
  {                                                            \
    logic [`bp_fe_fetch_operands_padding_width(vaddr_width_mp, vtag_width_mp, ptag_width_mp)-1:0] \
                  padding;                                     \
    bp_fe_vaddr_s vaddr;                                       \
  }  bp_fe_fetch_operands_s;                                   \
                                                               \
  typedef struct packed                                        \
  {                                                            \
    logic [ptag_width_mp-1:0]  ptag;                           \
    logic                      g;                              \
    logic                      u;                              \
    logic                      x;                              \
    logic                      w;                              \
    logic                      r;                              \
                                                               \
    logic                      uc;                             \
  } bp_fe_tlb_entry_s;                                         \
                                                               \
  typedef struct packed                                        \
  {                                                            \
    logic [`bp_fe_tlb_fill_operands_padding_width(vaddr_width_mp, vtag_width_mp, ptag_width_mp)-1:0] \
                              padding;                         \
    logic [vtag_width_mp-1:0] vtag;                            \
    bp_fe_tlb_entry_s         entry;                           \
  }  bp_fe_tlb_fill_operands_s;                                \
                                                               \
  typedef struct packed                                        \
  {                                                            \
    logic [`bp_fe_tlb_fence_operands_padding_width(vaddr_width_mp, vtag_width_mp, ptag_width_mp)-1:0] \
                               padding;                        \
    logic [vaddr_width_mp-1:0] vaddr;                          \
  }  bp_fe_tlb_fence_operands_s;                               \
                                                               \
  typedef struct packed                                        \
  {                                                            \
    union packed                                               \
    {                                                          \
      bp_fe_fetch_operands_s     fetch;                        \
      bp_fe_tlb_fill_operands_s  fill;                         \
      bp_fe_tlb_fence_operands_s fence;                        \
    }                   operands;                              \
    bp_fe_mem_cmd_op_e  op;                                    \
  }  bp_fe_mem_cmd_s;                                          \
                                                               \
  typedef struct packed                                        \
  {                                                            \
    logic                     itlb_miss;                       \
    logic                     instr_access_fault;              \
    logic                     icache_miss;                     \
    logic [instr_width_p-1:0] data;                            \
  }  bp_fe_mem_resp_s;

`define bp_fe_tlb_entry_width(ptag_width_mp) \
  (ptag_width_mp+6)

`define bp_fe_fetch_operands_width_no_padding(vaddr_width_mp) \
  (vaddr_width_mp)

`define bp_fe_tlb_fill_operands_width_no_padding(vtag_width_mp, ptag_width_mp) \
  (vtag_width_mp+`bp_fe_tlb_entry_width(ptag_width_mp))

`define bp_fe_tlb_fence_operands_width_no_padding(vaddr_width_mp) \
  (vaddr_width_mp)

`define bp_fe_mem_cmd_operands_u_width(vaddr_width_mp, vtag_width_mp, ptag_width_mp) \
  (1+`BSG_MAX(`bp_fe_fetch_operands_width_no_padding(vaddr_width_mp)                            \
              ,`BSG_MAX(`bp_fe_tlb_fill_operands_width_no_padding(vtag_width_mp, ptag_width_mp) \
                        ,`bp_fe_tlb_fence_operands_width_no_padding(vaddr_width_mp)             \
                        )                                                                       \
              )                                                                                 \
   )

`define bp_fe_fetch_operands_padding_width(vaddr_width_mp, vtag_width_mp, ptag_width_mp) \
  (`bp_fe_mem_cmd_operands_u_width(vaddr_width_mp, vtag_width_mp, ptag_width_mp) \
   -`bp_fe_fetch_operands_width_no_padding(vaddr_width_mp)                       \
   )

`define bp_fe_tlb_fill_operands_padding_width(vaddr_width_mp, vtag_width_mp, ptag_width_mp) \
  (`bp_fe_mem_cmd_operands_u_width(vaddr_width_mp, vtag_width_mp, ptag_width_mp) \
   -`bp_fe_tlb_fill_operands_width_no_padding(vtag_width_mp, ptag_width_mp)     \
   )

`define bp_fe_tlb_fence_operands_padding_width(vaddr_width_mp, vtag_width_mp, ptag_width_mp) \
  (`bp_fe_mem_cmd_operands_u_width(vaddr_width_mp, vtag_width_mp, ptag_width_mp) \
   -`bp_fe_tlb_fence_operands_width_no_padding(vaddr_width_mp)                   \
   )

`define bp_fe_mem_cmd_width(vaddr_width_mp, vtag_width_mp, ptag_width_mp) \
  ($bits(bp_fe_mem_cmd_op_e)+`bp_fe_mem_cmd_operands_u_width(vaddr_width_mp, vtag_width_mp, ptag_width_mp))

`define bp_fe_mem_resp_width \
  (3+instr_width_p)

`endif

