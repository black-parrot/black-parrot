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
 * bp_fe_instr_scan_s specifies metadata about the instruction, including FE-special opcodes
 *   and the calculated branch target
 */
`define declare_bp_fe_instr_scan_s(vaddr_width_mp) \
  typedef struct packed                    \
  {                                        \
    logic branch;                          \
    logic jal;                             \
    logic jalr;                            \
    logic call;                            \
    logic ret;                             \
    logic [vaddr_width_mp-1:0] imm;        \
  }  bp_fe_instr_scan_s;

`define declare_bp_fe_itlb_vaddr_s(vaddr_width_mp, sets_mp, cce_block_width_mp)                    \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic [vaddr_width_mp-`BSG_SAFE_CLOG2(sets_mp*cce_block_width_p/8)-1:0]    tag;                \
    logic [`BSG_SAFE_CLOG2(sets_mp)-1:0]                                       index;              \
    logic [`BSG_SAFE_CLOG2(cce_block_width_p/8)-1:0]                           offset;             \
  }  bp_fe_itlb_vaddr_s;   

`define declare_bp_fe_branch_metadata_fwd_s(btb_tag_width_mp, btb_idx_width_mp, bht_idx_width_mp, ghist_width_mp) \
  typedef struct packed                                                                         \
  {                                                                                             \
    logic                           pred_taken;                                                 \
    logic                           is_br;                                                      \
    logic                           is_jal;                                                     \
    logic                           is_jalr;                                                    \
    logic                           is_call;                                                    \
    logic                           is_ret;                                                     \
    logic                           src_btb;                                                    \
    logic                           src_ret;                                                    \
    logic                           src_ovr;                                                    \
    logic [btb_tag_width_mp-1:0]    btb_tag;                                                    \
    logic [btb_idx_width_mp-1:0]    btb_idx;                                                    \
    logic [bht_idx_width_mp-1:0]    bht_idx;                                                    \
    logic [ghist_width_mp-1:0]      ghist;                                                      \
  }  bp_fe_branch_metadata_fwd_s;

`define declare_bp_fe_pc_gen_stage_s(vaddr_width_mp, ghist_width_mp) \
  typedef struct packed             \
  {                                 \
    logic btb;                      \
    logic bht;                      \
    logic ret;                      \
    logic ovr;                      \
    logic taken;                    \
                                    \
    logic [vaddr_width_mp-1:0] pc;  \
    logic [ghist_width_mp-1:0] ghist; \
  }  bp_fe_pc_gen_stage_s

`define bp_fe_instr_scan_width(vaddr_width_mp) \
  (vaddr_width_mp + 5)

`define bp_fe_pc_gen_stage_width(vaddr_width_mp, ghist_width_mp) \
  (5 + vaddr_width_mp + ghist_width_mp)

`endif

