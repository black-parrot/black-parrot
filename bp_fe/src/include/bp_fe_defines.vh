/*
 * bp_fe_defines.vh
 *
 * bp_fe_defines.vh provides all the necessary structs for the Frontend submodules.
 * Backend supplies the frontend with branch prediction results and exceptions
 * codes. The Frontend should update the states accordingly.
 */

`ifndef BP_FE_DEFINES_VH
`define BP_FE_DEFINES_VH

/*
 * bp_fe_instr_scan_class_e specifies the type of the current instruction,
 * including whether the instruction is compressed or not.
 */
typedef enum logic [3:0]
{
  e_rvi_branch = 4'b0011
  ,e_rvi_jalr  = 4'b0010
  ,e_rvi_jal   = 4'b0001
  ,e_default   = 4'b0000
 } bp_fe_instr_scan_class_e;

/* 
 * bp_fe_instr_scan_s specifies metadata about the instruction, including FE-special opcodes
 *   and the calculated branch target
 */
`define declare_bp_fe_instr_scan_s(vaddr_width_mp) \
  typedef struct packed                    \
  {                                        \
    logic [vaddr_width_mp-1:0] imm;        \
    bp_fe_instr_scan_class_e   scan_class; \
  }  bp_fe_instr_scan_s;

`define declare_bp_fe_itlb_vaddr_s(vaddr_width_mp, sets_mp, cce_block_width_mp)                    \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic [vaddr_width_mp-`BSG_SAFE_CLOG2(sets_mp*cce_block_width_p/8)-1:0]    tag;                \
    logic [`BSG_SAFE_CLOG2(sets_mp)-1:0]                                       index;              \
    logic [`BSG_SAFE_CLOG2(cce_block_width_p/8)-1:0]                           offset;             \
  }  bp_fe_itlb_vaddr_s;   

`define declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_mp, btb_idx_width_mp, bht_idx_width_mp, ras_idx_width_mp) \
  typedef struct packed                                                                         \
  {                                                                                             \
    logic                           pred_taken;                                                 \
    logic [btb_tag_width_mp-1:0]    btb_tag;                                                    \
    logic [btb_idx_width_mp-1:0]    btb_idx;                                                    \
    logic [bht_idx_width_mp-1:0]    bht_idx;                                                    \
    logic [ras_idx_width_mp-1:0]    ras_idx;                                                    \
  }  bp_fe_branch_metadata_fwd_s;

`define declare_bp_fe_pc_gen_stage_s(vaddr_width_mp) \
  typedef struct packed             \
  {                                 \
    logic v;                        \
    logic pred_taken;               \
    logic ovr;                      \
                                    \
    logic [vaddr_width_p-1:0] pc;   \
  }  bp_fe_pc_gen_stage_s

`define bp_fe_instr_scan_width(vaddr_width_mp) \
  (vaddr_width_mp + $bits(bp_fe_instr_scan_class_e))

`define bp_fe_branch_metadata_fwd_width(btb_tag_width_mp, btb_idx_width_mp, bht_idx_width_mp, ras_idx_width_mp) \
  (1 + btb_tag_width_mp + btb_idx_width_mp + bht_idx_width_mp + ras_idx_width_mp)

`define bp_fe_pc_gen_stage_width(vaddr_width_mp) \
  (3 + vaddr_width_mp)

`endif

