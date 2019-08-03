/*
 * bp_fe_top.vh
 *
 * bp_fe_top.vh provides all the necessary structs for the Frontend submodules.
 * Backend supplies the frontend with branch prediction results and exceptions
 * codes. The Frontend should update the states accordingly.
*/

`ifndef BP_FE_PC_GEN_VH
`define BP_FE_PC_GEN_VH


`define declare_bp_fe_structs(vaddr_width_mp,paddr_width_mp,asid_width_mp,branch_metadata_fwd_width_mp)         \
  `declare_bp_fe_be_if(vaddr_width_mp,paddr_width_mp,asid_width_mp,branch_metadata_fwd_width_mp) \
                                                                                                                \
  typedef struct packed                                                                                         \
  {                                                                                                             \
    bp_fe_queue_type_e                  msg_type;                                                               \
    logic [`bp_fe_instr_scan_width-1:0] scan_instr;                                                             \
    union packed                                                                                                \
    {                                                                                                           \
      bp_fe_fetch_s                     fetch;                                                                  \
      bp_fe_exception_s                 exception;                                                              \
    }  msg;                                                                                                     \
  }  bp_fe_pc_gen_queue_s;                                                                                      \
                                                                                                                \
  /*                                                                                                            \
   * In the case of an I-TLB miss, bp_fe_itlb_miss_exception_data_s                                             \
   * struct is passed to the BE for I-TLB miss handling. This struct                                            \
   * includes the requested Virtual Page Nmuber (VPN) whose PTE does not                                        \
   * exist in the I-TLB.                                                                                        \
  */                                                                                                            \
  typedef struct packed                                                                                         \
  {                                                                                                             \
    bp_fe_command_queue_opcodes_e command_queue_opcodes;                                                        \
    union packed                                                                                                \
    {                                                                                                           \
      bp_fe_cmd_itlb_map_s    itlb_fill_response;                                                               \
      bp_fe_cmd_itlb_fence_s  itlb_fence;                                                                       \
    }  operands;                                                                                                \
  }  bp_fe_itlb_cmd_s;                                                                                          \
                                                                                                                \
   typedef struct packed                                                                                        \
  {                                                                                                             \
    bp_fe_queue_type_e   msg_type;                                                                              \
    union packed                                                                                                \
    {                                                                                                           \
      bp_fe_fetch_s      fetch;                                                                                 \
      bp_fe_exception_s  exception;                                                                             \
    }  msg;                                                                                                     \
  }  bp_fe_itlb_queue_s;



/*
 * bp_fe_instr_scan_class_e specifies the type of the current instruction,
 * including whether the instruction is compressed or not.
*/
typedef enum logic [3:0]
{
  e_rvi_branch
  , e_rvi_jalr
  , e_rvi_jal
  , e_default
 } bp_fe_instr_scan_class_e;

`define bp_fe_instr_scan_class_width ($bits(bp_fe_instr_scan_class_e))

/*
* bp_fe_instr_scan_s flags the category of the instruction. The control
* flow instruction under the inspections are branch, call, immediate call, jump
* and link, jump register, jump and return. If any of these instructions are
* compressed, the PC gen will use one of the instr_scan_class enum types to
* inform the other blocks. bp_fe_instr_scan_s consists of 1) whether pc is
* compressed or not and 2) what class pc instruction is.
*/
typedef struct packed
{
  logic                       is_compressed;
  bp_fe_instr_scan_class_e    instr_scan_class;
  logic [63:0]                imm;
}  bp_fe_instr_scan_s;


/*
 * bp_fe_itlb_icache_data_resp_s defines the interface between I-TLB and
 * I-Cache. The I-TLB sends the Physical Page Number (PPN) to the
 * I-Cache. The width of PPN is specified by ppn_width_p parameter.
*/
`define declare_bp_fe_itlb_icache_data_resp_s(ppn_width_mp) \
  typedef struct packed                                     \
  {                                                         \
    logic [ppn_width_mp-1:0] ppn;                           \
  }  bp_fe_itlb_icache_data_resp_s;

`define declare_bp_fe_itlb_vaddr_s(vaddr_width_mp, sets_mp, cce_block_width_mp)                    \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic [vaddr_width_mp-`BSG_SAFE_CLOG2(sets_mp*cce_block_width_p/8)-1:0]    tag;                \
    logic [`BSG_SAFE_CLOG2(sets_mp)-1:0]                                       index;              \
    logic [`BSG_SAFE_CLOG2(cce_block_width_p/8)-1:0]                           offset;             \
  }  bp_fe_itlb_vaddr_s;   

/*
 * The pc_gen logic recieves the commands from the backend if there is any
 * exceptions. These commands are either pc_redirect or attaboy.
*/

`define declare_bp_fe_pc_gen_cmd_s(vaddr_width_mp, branch_metadata_fwd_width_mp)  \
  typedef struct packed                                           \
  {                                                               \
    logic [vaddr_width_mp-1:0]     pc;                            \
    logic [branch_metadata_fwd_width_mp-1:0] branch_metadata_fwd; \
    logic reset_valid;                                            \
    logic pc_redirect_valid;                                      \
    logic attaboy_valid;                                          \
    logic itlb_fill_valid;                                        \
    logic icache_fence_valid;                                     \
    logic itlb_fence_valid;                                       \
  }  bp_fe_pc_gen_cmd_s;



/*
 * bp_fe_pc_gen_icache_s defines the interface between pc_gen and icache.
 * pc_gen informs the icache of the pc value.
*/
`define declare_bp_fe_pc_gen_icache_s(vaddr_width_mp)  \
  typedef struct packed                                \
  {                                                    \
    logic [vaddr_width_mp-1:0] virt_addr;              \
  }  bp_fe_pc_gen_icache_s;


/*
 * bp_fe_pc_gen_icache_s defines the interface between pc_gen and itlb.
 * The pc_gen informs the itlb of the pc address.
*/
`define declare_bp_fe_pc_gen_itlb_s(vaddr_width_mp)  \
  typedef struct packed                              \
  {                                                  \
    logic [vaddr_width_mp-1:0] virt_addr;            \
  }  bp_fe_pc_gen_itlb_s;


`define declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_mp,btb_idx_width_mp,bht_idx_width_mp,ras_idx_width_mp) \
  typedef struct packed                                                                          \
  {                                                                                              \
    logic [btb_tag_width_mp-1:0]    btb_tag;                                                     \
    logic [btb_idx_width_mp-1:0]    btb_idx;                                                    \
    logic [bht_idx_width_mp-1:0]    bht_idx;                                                    \
    logic [ras_idx_width_mp-1:0]   ras_idx;                                                    \
  }  bp_fe_branch_metadata_fwd_s;



/*
 * Declare all pc_gen widths at once as localparams
 * TODO: should this be in this file?
 */
`define declare_bp_fe_pc_gen_if_widths(vaddr_width_mp, branch_metadata_fwd_width_mp) \
  , localparam bp_fe_pc_gen_width_i_lp=`bp_fe_pc_gen_cmd_width(vaddr_width_mp,branch_metadata_fwd_width_mp)    \
  , localparam bp_fe_pc_gen_width_o_lp=`bp_fe_pc_gen_queue_width(vaddr_width_mp, branch_metadata_fwd_width_mp) \
  , localparam bp_fe_icache_pc_gen_width_lp=`bp_fe_icache_pc_gen_width(vaddr_width_mp)                         \
  , localparam bp_fe_pc_gen_icache_width_lp=vaddr_width_mp                                                     \
  , localparam bp_fe_pc_gen_itlb_width_lp=`bp_fe_pc_gen_itlb_width(vaddr_width_mp                              \
)

/*
 *  All the opcode macros for the control flow instructions.  These opcodes are
 * used in the Frontend for scanning compressed instructions.
*/
`define opcode_rvi_branch   7'h63
`define opcode_rvi_jalr     7'h67
`define opcode_rvi_jal      7'h6F


/*
 * bp_fe_is_rvc_e determine whether the control flow instructions are compressed
 * or not.
*/
`define bp_fe_is_compressed  1
`define bp_fe_not_compressed 0






`define bp_fe_pc_gen_queue_width(vaddr_width_mp,branch_metadata_fwd_width_mp) \
  (`bp_fe_queue_width(vaddr_width_mp,branch_metadata_fwd_width_mp)+`bp_fe_instr_scan_width)

`define bp_fe_pc_gen_cmd_width(vaddr_width_mp,branch_metadata_fwd_width_mp) \
  (vaddr_width_mp+branch_metadata_fwd_width_mp+6)

`define bp_fe_pc_gen_icache_width(vaddr_width_mp) (vaddr_width_mp)

`define bp_fe_pc_gen_itlb_width(vaddr_width_mp) (vaddr_width_mp)

`define bp_fe_instr_scan_width (1+`bp_fe_instr_scan_class_width+bp_eaddr_width_gp)

`define bp_fe_branch_metadata_fwd_width(btb_tag_width_mp,btb_idx_width_mp,bht_idx_width_mp,ras_idx_width_mp) \
(btb_tag_width_mp+btb_idx_width_mp+bht_idx_width_mp+ras_idx_width_mp)

`define bp_fe_itlb_icache_data_resp_width(ppn_width_mp) \
  (ppn_width_mp)

`define bp_fe_itlb_cmd_width(vaddr_width_mp,paddr_width_mp,asid_width_mp,branch_metadata_fwd_width_mp) \
  (`bp_fe_cmd_width(vaddr_width_mp,paddr_width_mp,asid_width_mp,branch_metadata_fwd_width_mp))

`define bp_fe_itlb_queue_width(vaddr_width_mp,branch_metadata_fwd_width_mp) \
  (`bp_fe_queue_width(vaddr_width_mp,branch_metadata_fwd_width_mp))

`define bp_fe_vtag_width(vaddr_width_mp, sets_mp, block_size_in_bytes_mp) \
  (vaddr_width_mp-`BSG_SAFE_CLOG2(sets_mp*block_size_in_bytes_mp))

`define bp_fe_ptag_width(paddr_width_mp, sets_mp, block_size_in_bytes_mp) \
  (paddr_width_mp-`BSG_SAFE_CLOG2(sets_mp*block_size_in_bytes_mp))

`endif
