/**
 *
 * bp_be_internal_if_defines.vh
 *
 */

`ifndef BP_BE_INTERNAL_IF_DEFINES_VH
`define BP_BE_INTERNAL_IF_DEFINES_VH

/*
 * Clients need only use this macro to declare all parameterized structs for FE<->BE interface.
 */
`define declare_bp_be_internal_if_structs(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic [vaddr_width_mp-1:0]               pc;                                                   \
    logic                                    fe_exception_not_instr;                               \
    bp_fe_exception_code_e                   fe_exception_code;                                    \
    logic [branch_metadata_fwd_width_mp-1:0] branch_metadata_fwd;                                  \
    rv64_instr_s                             instr;                                                \
    logic                                    csr_v;                                                \
    logic                                    mem_v;                                                \
    logic                                    long_v;                                               \
    logic                                    fence_v;                                              \
    logic                                    irs1_v;                                               \
    logic                                    irs2_v;                                               \
    logic                                    frs1_v;                                               \
    logic                                    frs2_v;                                               \
    logic                                    frs3_v;                                               \
   } bp_be_issue_pkt_s;                                                                            \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic                                    v;                                                    \
    logic                                    poison;                                               \
    logic [vaddr_width_mp-1:0]               pc;                                                   \
    rv64_instr_s                             instr;                                                \
    bp_be_decode_s                           decode;                                               \
                                                                                                   \
    logic                                    rs1_fp_v;                                             \
    logic [dpath_width_p-1:0]                rs1;                                                  \
    logic                                    rs2_fp_v;                                             \
    logic [dpath_width_p-1:0]                rs2;                                                  \
    logic                                    rs3_fp_v;                                             \
    logic [dpath_width_p-1:0]                imm;                                                  \
   } bp_be_dispatch_pkt_s;                                                                         \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic [vaddr_width_mp-1:0]         pc;                                                         \
    rv64_instr_s                       instr;                                                      \
                                                                                                   \
    logic                              v;                                                          \
    logic                              instr_v;                                                    \
    logic                              pipe_ctl_v;                                                 \
    logic                              pipe_int_v;                                                 \
    logic                              pipe_mem_early_v;                                           \
    logic                              pipe_aux_v;                                                 \
    logic                              pipe_mem_final_v;                                           \
    logic                              pipe_sys_v;                                                 \
    logic                              pipe_mul_v;                                                 \
    logic                              pipe_fma_v;                                                 \
    logic                              pipe_long_v;                                                \
                                                                                                   \
    logic                              csr_v;                                                      \
    logic                              mem_v;                                                      \
                                                                                                   \
    logic                              irf_w_v;                                                    \
    logic                              frf_w_v;                                                    \
    logic                              fflags_w_v;                                                 \
  }  bp_be_pipe_stage_reg_s;                                                                       \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    rv64_fflags_s             fflags;                                                              \
    logic [dpath_width_p-1:0] data;                                                                \
  }  bp_be_comp_stage_reg_s;                                                                       \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic                              instr_v;                                                    \
    logic                              fflags_w_v;                                                 \
    logic                              ctl_iwb_v;                                                  \
    logic                              aux_iwb_v;                                                  \
    logic                              aux_fwb_v;                                                  \
    logic                              int_iwb_v;                                                  \
    logic                              emem_iwb_v;                                                 \
    logic                              emem_fwb_v;                                                 \
    logic                              fmem_iwb_v;                                                 \
    logic                              fmem_fwb_v;                                                 \
    logic                              mul_iwb_v;                                                  \
    logic                              fma_fwb_v;                                                  \
    logic                              csr_v;                                                      \
    logic                              mem_v;                                                      \
                                                                                                   \
    logic [rv64_reg_addr_width_gp-1:0] rd_addr;                                                    \
   } bp_be_dep_status_s;                                                                           \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic                                    isd_v;                                                \
    logic [vaddr_width_mp-1:0]               isd_pc;                                               \
    logic [branch_metadata_fwd_width_mp-1:0] isd_branch_metadata_fwd;                              \
    logic                                    isd_fence_v;                                          \
    logic                                    isd_mem_v;                                            \
    logic                                    isd_long_v;                                           \
    logic                                    isd_csr_v;                                            \
    logic                                    isd_irs1_v;                                           \
    logic                                    isd_frs1_v;                                           \
    logic [rv64_reg_addr_width_gp-1:0]       isd_rs1_addr;                                         \
    logic                                    isd_irs2_v;                                           \
    logic                                    isd_frs2_v;                                           \
    logic [rv64_reg_addr_width_gp-1:0]       isd_rs2_addr;                                         \
    logic                                    isd_frs3_v;                                           \
    logic [rv64_reg_addr_width_gp-1:0]       isd_rs3_addr;                                         \
  }  bp_be_isd_status_s;                                                                           \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic                                    ex1_v;                                                \
    logic                                    ex1_instr_v;                                          \
    logic [vaddr_width_p-1:0]                ex1_npc;                                              \
    logic                                    ex1_br_or_jmp;                                        \
    logic                                    ex1_btaken;                                           \
                                                                                                   \
    logic                                    long_busy;                                            \
    logic                                    mem_busy;                                             \
    logic                                    commit_v;                                             \
                                                                                                   \
    /*                                                                                             \
     * 5 is the number of stages in the pipeline.                                                  \
     * In fact, we don't need all of this dependency information, since some of the stages are     \
     *    post-commit. However, for now we're passing all of it.                                   \
     */                                                                                            \
    bp_be_dep_status_s[5:0]                 dep_status;                                            \
  }  bp_be_calc_status_s;                                                                          \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic                        v;                                                                \
    logic                        queue_v;                                                          \
    logic                        instret;                                                          \
    logic [vaddr_width_p-1:0]    pc;                                                               \
    logic [vaddr_width_p-1:0]    npc;                                                              \
    logic [instr_width_p-1:0]    instr;                                                            \
  }  bp_be_commit_pkt_s;                                                                           \
                                                                                                   \
  /* TODO: make opcode */                                                                          \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic [vaddr_width_p-1:0]       npc;                                                           \
    logic [rv64_priv_width_gp-1:0]  priv_n;                                                        \
    logic                           translation_en_n;                                              \
    logic                           exception;                                                     \
    logic                           _interrupt;                                                    \
    logic                           eret;                                                          \
    logic                           fencei;                                                        \
    logic                           sfence;                                                        \
    logic                           satp;                                                          \
    logic                           rollback;                                                      \
  }  bp_be_trap_pkt_s;                                                                             \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic                        rd_w_v;                                                           \
    logic [reg_addr_width_p-1:0] rd_addr;                                                          \
    logic [dpath_width_p-1:0]    rd_data;                                                          \
    rv64_fflags_s                fflags_acc;                                                       \
  }  bp_be_wb_pkt_s;                                                                               \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic instr_miss_v;                                                                            \
    logic load_miss_v;                                                                             \
    logic store_miss_v;                                                                            \
    logic [vaddr_width_mp-1:0] pc;                                                                 \
    logic [vaddr_width_mp-1:0] vaddr;                                                              \
  }  bp_be_ptw_miss_pkt_s;                                                                         \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic itlb_fill_v;                                                                             \
    logic dtlb_fill_v;                                                                             \
    logic instr_page_fault_v;                                                                      \
    logic load_page_fault_v;                                                                       \
    logic store_page_fault_v;                                                                      \
    logic [vaddr_width_mp-1:0] pc;                                                                 \
    logic [vaddr_width_mp-1:0] vaddr;                                                              \
    logic [dword_width_p-1:0]  entry;                                                              \
  }  bp_be_ptw_fill_pkt_s;                                                                         \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic [rv64_priv_width_gp-1:0] priv_mode;                                                      \
    logic [ptag_width_p-1:0]       satp_ppn;                                                       \
    logic                          translation_en;                                                 \
    logic                          mstatus_sum;                                                    \
    logic                          mstatus_mxr;                                                    \
  }  bp_be_trans_info_s;


/* Declare width macros so that clients can use structs in ports before struct declaration
 * Each of these macros needs to be kept in sync with the struct definition. The computation
 *   comes from literally counting bits in the struct definition, which is ugly, error-prone,
 *   and an unfortunate, necessary consequence of parameterized structs.
 */
`define bp_be_issue_pkt_width(vaddr_width_mp, branch_metadata_fwd_width_mp) \
  (vaddr_width_mp                                                                                  \
   + 1                                                                                             \
   + $bits(bp_fe_exception_code_e)                                                                 \
   + branch_metadata_fwd_width_mp                                                                  \
   + rv64_instr_width_gp                                                                           \
   + 9                                                                                             \
   )

`define bp_be_dispatch_pkt_width(vaddr_width_mp) \
  (2                                                                                               \
   + vaddr_width_mp                                                                                \
   + rv64_instr_width_gp                                                                           \
   + 3                                                                                             \
   + 3 * dpath_width_p                                                                             \
   + `bp_be_decode_width                                                                           \
   )

`define bp_be_pipe_stage_reg_width(vaddr_width_mp) \
   (vaddr_width_mp                                                                                 \
   + rv64_instr_width_gp                                                                           \
   + 16                                                                                            \
   )

`define bp_be_comp_stage_reg_width \
  ($bits(rv64_fflags_s) + dpath_width_p)

`define bp_be_isd_status_width(vaddr_width_mp, branch_metadata_fwd_width_mp) \
  (1 + vaddr_width_mp + branch_metadata_fwd_width_mp + 9 + 3*rv64_reg_addr_width_gp)

`define bp_be_dep_status_width \
  (14 + rv64_reg_addr_width_gp)

`define bp_be_calc_status_width(vaddr_width_mp) \
  (2                                                                                               \
   + vaddr_width_p                                                                                 \
   + 5                                                                                             \
   + 6 * `bp_be_dep_status_width                                                                   \
   )

`define bp_be_commit_pkt_width(vaddr_width_mp) \
  (3                                                                                               \
   + 2 * vaddr_width_mp                                                                            \
   + instr_width_p                                                                                 \
   )

`define bp_be_trap_pkt_width(vaddr_width_mp) \
  (1 * vaddr_width_mp + rv64_priv_width_gp + 8)

`define bp_be_wb_pkt_width(vaddr_width_mp) \
  (1                                                                                               \
   + reg_addr_width_p                                                                              \
   + dpath_width_p                                                                                 \
   + $bits(rv64_fflags_s)                                                                          \
   )

`define bp_be_ptw_miss_pkt_width(vaddr_width_mp) \
  (3 + 2*vaddr_width_mp)

`define bp_be_ptw_fill_pkt_width(vaddr_width_mp) \
  (5                                                                                               \
   + 2*vaddr_width_mp                                                                              \
   + dword_width_p                                                                                 \
   )

`define bp_be_trans_info_width(ptag_width_mp) \
  (rv64_priv_width_gp+ptag_width_mp+3)

`endif

