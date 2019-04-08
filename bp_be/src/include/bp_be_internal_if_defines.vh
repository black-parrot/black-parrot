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
    logic [bp_be_itag_width_gp-1:0]          itag;                                                 \
    logic [rv64_eaddr_width_gp-1:0]          pc;                                                   \
    logic                                    fe_exception_not_instr;                               \
    bp_fe_exception_code_e                   fe_exception_code;                                    \
   } bp_be_instr_metadata_s;                                                                       \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    bp_be_instr_metadata_s                   instr_metadata;                                       \
    logic [branch_metadata_fwd_width_mp-1:0] branch_metadata_fwd;                                  \
    logic [rv64_instr_width_gp-1:0]          instr;                                                \
    logic                                    irs1_v;                                               \
    logic                                    irs2_v;                                               \
    logic                                    frs1_v;                                               \
    logic                                    frs2_v;                                               \
    logic [rv64_reg_addr_width_gp-1:0]       rs1_addr;                                             \
    logic [rv64_reg_addr_width_gp-1:0]       rs2_addr;                                             \
    logic [rv64_reg_data_width_gp-1:0]       imm;                                                  \
   } bp_be_issue_pkt_s;                                                                            \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    bp_be_instr_metadata_s                   instr_metadata;                                       \
    logic [branch_metadata_fwd_width_mp-1:0] branch_metadata_fwd;                                  \
    logic [rv64_instr_width_gp-1:0]          instr;                                                \
    bp_be_decode_s                           decode;                                               \
                                                                                                   \
    logic [rv64_reg_data_width_gp-1:0]       rs1;                                                  \
    logic [rv64_reg_data_width_gp-1:0]       rs2;                                                  \
    logic [rv64_reg_data_width_gp-1:0]       imm;                                                  \
   } bp_be_dispatch_pkt_s;                                                                         \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    bp_be_instr_metadata_s             instr_metadata;                                             \
    logic [rv64_instr_width_gp-1:0]    instr;                                                      \
                                                                                                   \
    logic                              instr_v;                                                    \
    logic                              pipe_comp_v;                                                \
    logic                              pipe_int_v;                                                 \
    logic                              pipe_mul_v;                                                 \
    logic                              pipe_mem_v;                                                 \
    logic                              pipe_fp_v;                                                  \
                                                                                                   \
    logic                              irf_w_v;                                                    \
    logic                              frf_w_v;                                                    \
    logic [rv64_reg_addr_width_gp-1:0] rd_addr;                                                    \
  }  bp_be_pipe_stage_reg_s;                                                                       \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic                              int_iwb_v;                                                  \
    logic                              mul_iwb_v;                                                  \
    logic                              mem_iwb_v;                                                  \
    logic                              mem_fwb_v;                                                  \
    logic                              fp_fwb_v;                                                   \
    logic                              stall_v;                                                    \
                                                                                                   \
    logic [rv64_reg_addr_width_gp-1:0] rd_addr;                                                    \
   } bp_be_dep_status_s;                                                                           \
                                                                                                   \
  typedef struct packed                                                                            \
  {                                                                                                \
    logic                                    isd_v;                                                \
    logic                                    isd_irs1_v;                                           \
    logic                                    isd_frs1_v;                                           \
    logic [rv64_reg_addr_width_gp-1:0]       isd_rs1_addr;                                         \
    logic                                    isd_irs2_v;                                           \
    logic                                    isd_frs2_v;                                           \
    logic [rv64_reg_addr_width_gp-1:0]       isd_rs2_addr;                                         \
                                                                                                   \
    logic                                    int1_v;                                               \
    logic [rv64_eaddr_width_gp-1:0]          int1_br_tgt;                                          \
    logic [branch_metadata_fwd_width_mp-1:0] int1_branch_metadata_fwd;                             \
    logic                                    int1_br_or_jmp;                                       \
    logic                                    int1_btaken;                                          \
                                                                                                   \
    logic                                    ex1_v;                                                \
    logic [rv64_eaddr_width_gp-1:0]          ex1_pc;                                               \
                                                                                                   \
    /*                                                                                             \
     * 5 is the number of stages in the pipeline.                                                  \
     * In fact, we don't need all of this dependency information, since some of the stages are     \
     *    post-commit. However, for now we're passing all of it.                                   \
     */                                                                                            \
    bp_be_dep_status_s[4:0]                 dep_status;                                            \
                                                                                                   \
    logic                                   mem3_v;                                                \
    logic [rv64_eaddr_width_gp-1:0]         mem3_pc;                                               \
    logic                                   mem3_cache_miss_v;                                     \
    logic                                   mem2_tlb_miss_v;                                       \
    logic                                   mem3_tlb_miss_v;                                       \
    logic                                   mem3_exception_v;                                      \
    logic                                   mem3_ret_v;                                            \
                                                                                                   \
    logic                                   instr_cmt_v;                                           \
  }  bp_be_calc_status_s;                                                                          \

/* Declare width macros so that clients can use structs in ports before struct declaration
 * Each of these macros needs to be kept in sync with the struct definition. The computation
 *   comes from literally counting bits in the struct definition, which is ugly, error-prone,
 *   and an unfortunate, necessary consequence of parameterized structs.
 */
`define bp_be_instr_metadata_width                                                                 \
  (bp_be_itag_width_gp                                                                             \
   + rv64_eaddr_width_gp                                                                           \
   + 1                                                                                             \
   + $bits(bp_fe_exception_code_e)                                                                 \
   )                                                                                               

`define bp_be_issue_pkt_width(branch_metadata_fwd_width_mp)                                        \
  (`bp_be_instr_metadata_width                                                                     \
   + branch_metadata_fwd_width_mp                                                                  \
   + rv64_instr_width_gp                                                                           \
   + 4                                                                                             \
   + 2 * rv64_reg_addr_width_gp                                                                    \
   + rv64_reg_data_width_gp                                                                        \
   )                                                                                               

`define bp_be_dispatch_pkt_width(branch_metadata_fwd_width_mp)                                     \
  (`bp_be_instr_metadata_width                                                                     \
   + branch_metadata_fwd_width_mp                                                                  \
   + rv64_instr_width_gp                                                                           \
   + 3 * rv64_reg_data_width_gp                                                                    \
   + `bp_be_decode_width                                                                           \
   )                                                                                               

`define bp_be_pipe_stage_reg_width                                                                 \
  (`bp_be_instr_metadata_width                                                                     \
   +rv64_instr_width_gp                                                                            \
   +8                                                                                              \
   +rv64_reg_addr_width_gp                                                                         \
   )

`define bp_be_dep_status_width                                                                     \
  (6 + rv64_reg_addr_width_gp)                                                                     

`define bp_be_calc_status_width(branch_metadata_fwd_width_mp)                                      \
  (1                                                                                               \
   + rv64_eaddr_width_gp                                                                           \
   + 2                                                                                             \
   + rv64_reg_addr_width_gp                                                                        \
   + 2                                                                                             \
   + rv64_reg_addr_width_gp+1                                                                      \
   + rv64_eaddr_width_gp+branch_metadata_fwd_width_mp                                              \
   + 3                                                                                             \
   + 5 * `bp_be_dep_status_width                                                                   \
   + 1                                                                                             \
   + rv64_eaddr_width_gp                                                                           \
   + 6                                                                                             \
   )                                                                                               

`endif

