/**
 *
 * bp_be_defines.svh
 *
 */

`ifndef BP_BE_DEFINES_SVH
`define BP_BE_DEFINES_SVH

  `include "bsg_defines.sv"
  `include "bp_common_core_if.svh"
  `include "bp_be_dcache_defines.svh"
  `include "HardFloat_consts.vi"
  `include "HardFloat_specialize.vi"

  /*
   * Clients need only use this macro to declare all parameterized structs for FE<->BE interface.
   */
  `define declare_bp_be_internal_if_structs(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic                                    irs1_v;                                             \
      logic                                    irs2_v;                                             \
      logic                                    frs1_v;                                             \
      logic                                    frs2_v;                                             \
      logic                                    frs3_v;                                             \
      rv64_instr_s                             instr;                                              \
      logic [fetch_ptr_gp-1:0]                 size;                                               \
    }  bp_be_preissue_pkt_s;                                                                       \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic                                    v;                                                  \
      logic                                    fetch;                                              \
      logic                                    itlb_miss;                                          \
      logic                                    instr_access_fault;                                 \
      logic                                    instr_page_fault;                                   \
      logic                                    icache_miss;                                        \
      logic                                    illegal_instr;                                      \
      logic                                    ecall_m;                                            \
      logic                                    ecall_s;                                            \
      logic                                    ecall_u;                                            \
      logic                                    ebreak;                                             \
      logic                                    dbreak;                                             \
      logic                                    dret;                                               \
      logic                                    mret;                                               \
      logic                                    sret;                                               \
      logic                                    wfi;                                                \
      logic                                    sfence_vma;                                         \
      logic                                    fencei;                                             \
      logic                                    csrw;                                               \
                                                                                                   \
      logic [vaddr_width_mp-1:0]               pc;                                                 \
      rv64_instr_s                             instr;                                              \
      logic [fetch_ptr_gp-1:0]                 count;                                              \
      logic [fetch_ptr_gp-1:0]                 size;                                               \
      bp_be_decode_s                           decode;                                             \
      logic [dpath_width_gp-1:0]               imm;                                                \
      logic [branch_metadata_fwd_width_mp-1:0] branch_metadata_fwd;                                \
    }  bp_be_issue_pkt_s;                                                                          \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic                                    v;                                                  \
      logic                                    queue_v;                                            \
      logic                                    ispec_v;                                            \
      logic                                    nspec_v;                                            \
      logic [vaddr_width_mp-1:0]               pc;                                                 \
      rv64_instr_s                             instr;                                              \
      logic [fetch_ptr_gp-1:0]                 size;                                               \
      logic [fetch_ptr_gp-1:0]                 count;                                              \
      bp_be_decode_s                           decode;                                             \
                                                                                                   \
      logic [dpath_width_gp-1:0]               rs1;                                                \
      logic [dpath_width_gp-1:0]               rs2;                                                \
      logic [dpath_width_gp-1:0]               imm;                                                \
      bp_be_exception_s                        exception;                                          \
      bp_be_special_s                          special;                                            \
    }  bp_be_dispatch_pkt_s;                                                                       \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic                                    v;                                                  \
      logic [vaddr_width_mp-1:0]               pc;                                                 \
      rv64_instr_s                             instr;                                              \
      bp_be_decode_s                           decode;                                             \
      logic [fetch_ptr_gp-1:0]                 size;                                               \
      logic [fetch_ptr_gp-1:0]                 count;                                              \
                                                                                                   \
      logic [int_rec_width_gp-1:0]             isrc1;                                              \
      logic [int_rec_width_gp-1:0]             isrc2;                                              \
      logic [int_rec_width_gp-1:0]             isrc3;                                              \
      logic [dp_rec_width_gp-1:0]              fsrc1;                                              \
      logic [dp_rec_width_gp-1:0]              fsrc2;                                              \
      logic [dp_rec_width_gp-1:0]              fsrc3;                                              \
    }  bp_be_reservation_s;                                                                        \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic                              v;                                                        \
      logic                              fflags_v;                                                 \
      logic                              aux_iwb_v;                                                \
      logic                              aux_fwb_v;                                                \
      logic                              eint_iwb_v;                                               \
      logic                              eint_fwb_v;                                               \
      logic                              fint_iwb_v;                                               \
      logic                              fint_fwb_v;                                               \
      logic                              emem_iwb_v;                                               \
      logic                              emem_fwb_v;                                               \
      logic                              fmem_iwb_v;                                               \
      logic                              fmem_fwb_v;                                               \
      logic                              mul_iwb_v;                                                \
      logic                              mul_fwb_v;                                                \
      logic                              fma_iwb_v;                                                \
      logic                              fma_fwb_v;                                                \
      logic                              long_iwb_v;                                               \
      logic                              long_fwb_v;                                               \
                                                                                                   \
      logic [rv64_reg_addr_width_gp-1:0] rd_addr;                                                  \
    }  bp_be_dep_status_s;                                                                         \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic                     v;                                                                 \
      logic                     branch;                                                            \
      logic                     btaken;                                                            \
      logic                     bspec;                                                             \
      logic [vaddr_width_p-1:0] npc;                                                               \
    }  bp_be_branch_pkt_s;                                                                         \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic                      v;                                                                \
      logic                      queue_v;                                                          \
      logic                      instret;                                                          \
      logic [vaddr_width_p-1:0]  npc;                                                              \
      logic [vaddr_width_p-1:0]  vaddr;                                                            \
      logic [dpath_width_gp-1:0] data;                                                             \
      rv64_instr_s               instr;                                                            \
      logic [fetch_ptr_gp-1:0]   size;                                                             \
      logic [fetch_ptr_gp-1:0]   count;                                                            \
      bp_be_exception_s          exception;                                                        \
      bp_be_special_s            special;                                                          \
      logic                      iscore;                                                           \
      logic                      fscore;                                                           \
    }  bp_be_retire_pkt_s;                                                                         \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic [paddr_width_mp-page_offset_width_gp-1:0] ptag;                                        \
      logic                                           gigapage;                                    \
      logic                                           megapage;                                    \
      logic                                           a;                                           \
      logic                                           d;                                           \
      logic                                           u;                                           \
      logic                                           x;                                           \
      logic                                           w;                                           \
      logic                                           r;                                           \
    }  bp_be_pte_leaf_s;                                                                           \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic                           npc_w_v;                                                     \
      logic                           queue_v;                                                     \
      logic                           instret;                                                     \
      logic [fetch_ptr_gp-1:0]        size;                                                        \
      logic [fetch_ptr_gp-1:0]        count;                                                       \
      logic [vaddr_width_p-1:0]       pc;                                                          \
      logic [vaddr_width_p-1:0]       npc;                                                         \
      logic [vaddr_width_p-1:0]       vaddr;                                                       \
      rv64_instr_s                    instr;                                                       \
      bp_be_pte_leaf_s                pte_leaf;                                                    \
      logic [rv64_priv_width_gp-1:0]  priv_n;                                                      \
      logic                           translation_en_n;                                            \
      logic                           exception;                                                   \
      logic                           _interrupt;                                                  \
      logic                           resume;                                                      \
      logic                           eret;                                                        \
      logic                           fencei;                                                      \
      logic                           sfence;                                                      \
      logic                           csrw;                                                        \
      logic                           wfi;                                                         \
      logic                           itlb_miss;                                                   \
      logic                           icache_miss;                                                 \
      logic                           dtlb_store_miss;                                             \
      logic                           dtlb_load_miss;                                              \
      logic                           dcache_miss;                                                 \
      logic                           dcache_replay;                                               \
      logic                           itlb_fill_v;                                                 \
      logic                           dtlb_fill_v;                                                 \
      logic                           iscore_v;                                                    \
      logic                           fscore_v;                                                    \
    }  bp_be_commit_pkt_s;                                                                         \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic                         ird_w_v;                                                       \
      logic                         frd_w_v;                                                       \
      logic                         ptw_w_v;                                                       \
      logic [reg_addr_width_gp-1:0] rd_addr;                                                       \
      logic [dpath_width_gp-1:0]    rd_data;                                                       \
      rv64_fflags_s                 fflags;                                                        \
    }  bp_be_wb_pkt_s;                                                                             \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic [rv64_priv_width_gp-1:0] priv_mode;                                                    \
      logic [ptag_width_p-1:0]       base_ppn;                                                     \
      logic                          translation_en;                                               \
      logic                          mstatus_sum;                                                  \
      logic                          mstatus_mxr;                                                  \
    }  bp_be_trans_info_s;                                                                         \
                                                                                                   \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic                          u_mode;                                                       \
      logic                          s_mode;                                                       \
      logic                          m_mode;                                                       \
      logic                          debug_mode;                                                   \
      logic                          tsr;                                                          \
      logic                          tw;                                                           \
      logic                          tvm;                                                          \
      logic                          ebreakm;                                                      \
      logic                          ebreaks;                                                      \
      logic                          ebreaku;                                                      \
      logic                          fpu_en;                                                       \
      logic                          cycle_en;                                                     \
      logic                          instret_en;                                                   \
    }  bp_be_decode_info_s


  /* Declare width macros so that clients can use structs in ports before struct declaration
   * Each of these macros needs to be kept in sync with the struct definition. The computation
   *   comes from literally counting bits in the struct definition, which is ugly, error-prone,
   *   and an unfortunate, necessary consequence of parameterized structs.
   */
  `define bp_be_preissue_pkt_width \
    (5+rv64_instr_width_gp+fetch_ptr_gp)

  `define bp_be_issue_pkt_width(vaddr_width_mp, branch_metadata_fwd_width_mp) \
    (6+vaddr_width_mp+instr_width_gp+2*fetch_ptr_gp+$bits(bp_be_decode_s)+dpath_width_gp+branch_metadata_fwd_width_mp+13)

  `define bp_be_dispatch_pkt_width(vaddr_width_mp) \
    (4+vaddr_width_mp+rv64_instr_width_gp+2*fetch_ptr_gp+3*dpath_width_gp+$bits(bp_be_decode_s)+$bits(bp_be_exception_s)+$bits(bp_be_special_s))

  `define bp_be_reservation_width(vaddr_width_mp) \
    (1+vaddr_width_mp+rv64_instr_width_gp+2*fetch_ptr_gp+$bits(bp_be_decode_s)+3*int_rec_width_gp+3*dp_rec_width_gp)

  `define bp_be_branch_pkt_width(vaddr_width_mp) \
    (4+vaddr_width_mp)

  `define bp_be_retire_pkt_width(vaddr_width_mp) \
    (5+dpath_width_gp+2*vaddr_width_mp+instr_width_gp+2*fetch_ptr_gp+$bits(bp_be_exception_s)+$bits(bp_be_special_s))

  `define bp_be_pte_leaf_width(paddr_width_mp) \
    (paddr_width_mp - page_offset_width_gp + 8)

  `define bp_be_commit_pkt_width(vaddr_width_mp, paddr_width_mp) \
    (4+`bp_be_pte_leaf_width(paddr_width_mp)+3*vaddr_width_mp+instr_width_gp+2*fetch_ptr_gp+rv64_priv_width_gp+18)

  `define bp_be_wb_pkt_width(vaddr_width_mp) \
    (3+reg_addr_width_gp+dpath_width_gp+$bits(rv64_fflags_s))

  `define bp_be_trans_info_width(ptag_width_mp) \
    (rv64_priv_width_gp+ptag_width_mp+3)

  `define bp_be_decode_info_width \
    (rv64_priv_width_gp+11)

`endif

