/*
 * bp_fe_top.vh
 *
 * bp_fe_top.vh provides all the necessary structs for the Frontend submodules.
 * Backend supplies the frontend with branch prediction results and exceptions
 * codes. The Frontend should update the states accordingly.
*/

`ifndef BP_FE_PC_GEN_VH
`define BP_FE_PC_GEN_VH

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
}  bp_fe_instr_scan_s;


`define declare_bp_fe_itlb_vaddr_s(vaddr_width_mp, sets_mp, cce_block_width_mp)                    \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic [vaddr_width_mp-`BSG_SAFE_CLOG2(sets_mp*cce_block_width_p/8)-1:0]    tag;                \
    logic [`BSG_SAFE_CLOG2(sets_mp)-1:0]                                       index;              \
    logic [`BSG_SAFE_CLOG2(cce_block_width_p/8)-1:0]                           offset;             \
  }  bp_fe_itlb_vaddr_s;   

`define declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_mp,btb_idx_width_mp,bht_idx_width_mp,ras_idx_width_mp) \
  typedef struct packed                                                                          \
  {                                                                                              \
    logic [btb_tag_width_mp-1:0]    btb_tag;                                                     \
    logic [btb_idx_width_mp-1:0]    btb_idx;                                                    \
    logic [bht_idx_width_mp-1:0]    bht_idx;                                                    \
    logic [ras_idx_width_mp-1:0]   ras_idx;                                                    \
  }  bp_fe_branch_metadata_fwd_s;

/*
 *  All the opcode macros for the control flow instructions.  These opcodes are
 * used in the Frontend for scanning compressed instructions.
*/
`define opcode_rvi_branch   7'h63
`define opcode_rvi_jalr     7'h67
`define opcode_rvi_jal      7'h6F


`define bp_fe_instr_scan_width (1+`bp_fe_instr_scan_class_width)

`define bp_fe_branch_metadata_fwd_width(btb_tag_width_mp,btb_idx_width_mp,bht_idx_width_mp,ras_idx_width_mp) \
(btb_tag_width_mp+btb_idx_width_mp+bht_idx_width_mp+ras_idx_width_mp)

`define bp_fe_vtag_width(vaddr_width_mp, sets_mp, block_size_in_bytes_mp) \
  (vaddr_width_mp-`BSG_SAFE_CLOG2(sets_mp*block_size_in_bytes_mp))

`define bp_fe_ptag_width(paddr_width_mp, sets_mp, block_size_in_bytes_mp) \
  (paddr_width_mp-`BSG_SAFE_CLOG2(sets_mp*block_size_in_bytes_mp))

`endif
