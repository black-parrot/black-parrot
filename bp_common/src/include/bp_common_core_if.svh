/**
 *
 * bp_common_core_if.svh
 *
 * bp_core_interface.svh declares the interface between the BlackParrot Front End
 * and Back End For simplicity and flexibility, these signals are declared as
 * parameterizable structures. Each structure declares its width separately to
 * avoid preprocessor ordering issues.
 *
 * Logically, the BE controls the FE and may command the FE to flush all the states,
 * redirect the PC, etc. The FE uses its queue to supply the BE with (possibly
 * speculative) instruction/PC pairs and inform the BE of any exceptions that have
 * occurred within the unit (e.g., misaligned instruction fetch) so the BE may
 * ensure all exceptions are taken precisely.  The BE checks the PC in the
 * instruction/PC pairs to make sure that the FE predictions correspond to
 * correct architectural execution.
 *
 * NOTE: VCS can only handle packed unions where each member is the same size. Therefore, we
 *         need to do some macro hacking to get parameterized unions to work nicely.
 * NOTE: Potentially could make sense to separate two unidirectional interface files. This one
 *         is a little overwhelming.
 */

`ifndef BP_COMMON_CORE_IF_SVH
`define BP_COMMON_CORE_IF_SVH

  /*
   * Clients need only use this macro to declare all parameterized structs for FE<->BE interface.
   */
  `define declare_bp_core_if(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
    /*                                                                                             \
     *                                                                                             \
     * bp_fe_queue_s contains the pc/instruction pair, along branch metadata for the branch        \
     * predictor to update its internal data based on feedback from the BE as to                   \
     * whether this particular PC/instruction pair was correct.  The BE does not look              \
     * at the branch metadata, since this would mean that the BE implementation is                 \
     * tightly coupled to the FE implementation.                                                   \
     * Exceptions serviced inline with instructions. Otherwise we have no way of knowing if this   \
     * exception is eclipsed by a preceding branch mispredict. Therefore, we support exceptions as \
     * alternate message types.                                                                    \
     */                                                                                            \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic [vaddr_width_mp-1:0]                pc;                                                \
      logic [fetch_width_p-1:0]                 instr;                                             \
      logic [branch_metadata_fwd_width_mp-1:0]  branch_metadata_fwd;                               \
      logic [fetch_ptr_p-1:0]                   count;                                             \
      bp_fe_queue_type_e                        msg_type;                                          \
    }  bp_fe_queue_s;                                                                              \
                                                                                                   \
    /*                                                                                             \
     * bp_fe_cmd_pc_redirect_operands_s provides the information needed during the pc              \
     * redirection.  command_queue_subopcode provides the reasons for pc redirection.              \
     * branch_metadata_fwd provides the information of branch misprediction.                       \
     * translation_en tells whether the pc is virtual or physical in the case of context switch.   \
     * priv is the privilege mode being switched to.                                               \
    */                                                                                             \
    typedef struct packed                                                                          \
    {                                                                                              \
      bp_fe_command_queue_subopcodes_e         subopcode;                                          \
      logic [branch_metadata_fwd_width_mp-1:0] branch_metadata_fwd;                                \
      bp_fe_misprediction_reason_e             misprediction_reason;                               \
      logic                                    translation_en;                                     \
      logic [1:0]                              priv;                                               \
                                                                                                   \
      logic [`bp_fe_cmd_pc_redirect_operands_padding_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp)-1:0] \
                                               padding;                                            \
    }  bp_fe_cmd_pc_redirect_operands_s;                                                           \
                                                                                                   \
    /*                                                                                             \
     * bp_fe_attaboy_s provides branch prediction metadata back to the FE on the case of           \
     * correct prediction, so that the FE can update its predictors accordingly.                   \
     */                                                                                            \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic                                    taken;                                              \
      logic [branch_metadata_fwd_width_mp-1:0] branch_metadata_fwd;                                \
                                                                                                   \
      logic [`bp_fe_cmd_attaboy_padding_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp)-1:0] \
                                               padding;                                            \
    }  bp_fe_cmd_attaboy_s;                                                                        \
                                                                                                   \
    /*                                                                                             \
     * bp_pte_leaf_s provides the information needed in the case of the page                       \
     * walk. The bp_pte_leaf_s contains the physical address and the                               \
     * additional bits in the page table entry (pte).                                              \
     */                                                                                            \
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
    }  bp_pte_leaf_s;                                                                              \
                                                                                                   \
    /*                                                                                             \
     * bp_fe_cmd_itlb_fill_s provides the virtual, physical translation plus the                   \
     * additional permission bits to the itlb in the case of page walk. Once the                   \
     * frontend sends the page fill request to the backend, the backend performs the               \
     * page walk, and responds to the frontend with bp_fe_cmd_itlb_fill_s.                         \
     */                                                                                            \
    typedef struct packed                                                                          \
    {                                                                                              \
      bp_pte_leaf_s              pte_leaf;                                                         \
      logic [instr_width_gp-1:0] instr;                                                            \
      logic [fetch_ptr_p-1:0]    count;                                                            \
      logic [`bp_fe_cmd_itlb_fill_padding_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp)-1:0] \
                                 padding;                                                          \
    }  bp_fe_cmd_itlb_fill_s;                                                                      \
                                                                                                   \
    /*                                                                                             \
     * bp_fe_cmd_icache_fill_s indicates the alignment offset of the original                      \
     * miss which triggered this fill request. It carries partial instructions;                    \
     * the frontend will issue the remaining memory request upon receipt.                          \
     */                                                                                            \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic [instr_width_gp-1:0] instr;                                                            \
      logic [fetch_ptr_p-1:0]    count;                                                            \
      logic [`bp_fe_cmd_icache_fill_padding_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp)-1:0] \
                                 padding;                                                          \
    }  bp_fe_cmd_icache_fill_s;                                                                    \
                                                                                                   \
    /*                                                                                             \
     * bp_fe_cmd_itlb_fence_s consists of virtual address, asid, and flags for whether to flush    \
     * all addresses and/or all asids. In the case of context switch, the itlb will perform itlb   \
     * fence according to the asid.                                                                \
     */                                                                                            \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic [asid_width_mp-1:0]  asid;                                                             \
      logic                      flush_all_addresses;                                              \
      logic                      flush_all_asid;                                                   \
      logic [`bp_fe_cmd_itlb_fence_padding_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp)-1:0] \
                                 padding;                                                          \
    }  bp_fe_cmd_itlb_fence_s;                                                                     \
                                                                                                   \
    /*                                                                                             \
     * bp_fe_cmd_s is the information backend provides to the frontend in the case of              \
     * misprediction.  It contains the branch_metadata_fwd information and                         \
     * misprediction reason. The BE does not examine the branch metadata, but does                 \
     * supply the misprediction reason.                                                            \
     */                                                                                            \
    typedef struct packed                                                                          \
    {                                                                                              \
      logic [vaddr_width_mp-1:0]          npc;                                                     \
      bp_fe_command_queue_opcodes_e       opcode;                                                  \
      union packed                                                                                 \
      {                                                                                            \
        bp_fe_cmd_pc_redirect_operands_s    pc_redirect_operands;                                  \
        bp_fe_cmd_attaboy_s                 attaboy;                                               \
        bp_fe_cmd_itlb_fill_s               itlb_fill_response;                                    \
        bp_fe_cmd_itlb_fence_s              itlb_fence;                                            \
        bp_fe_cmd_icache_fill_s             icache_fill_response;                                  \
      }  operands;                                                                                 \
    }  bp_fe_cmd_s

  /*
   * Declare all fe-be widths at once as localparams
   */
  `define declare_bp_core_if_widths(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
    , localparam fe_queue_width_lp=`bp_fe_queue_width(vaddr_width_mp, branch_metadata_fwd_width_mp) \
    , localparam fe_cmd_width_lp=`bp_fe_cmd_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp)

  /* Declare width macros so that clients can use structs in ports before struct declaration */
  `define bp_fe_queue_width(vaddr_width_mp, branch_metadata_fwd_width_mp)                          \
    ($bits(bp_fe_queue_type_e)+branch_metadata_fwd_width_mp+fetch_width_p+fetch_ptr_p+vaddr_width_mp)

  `define bp_fe_cmd_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
    (vaddr_width_mp                                                                                \
     + $bits(bp_fe_command_queue_opcodes_e)                                                        \
     + `bp_fe_cmd_operands_u_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp)    \
     )

  `define bp_fe_cmd_pc_redirect_operands_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
    (`bp_fe_cmd_operands_u_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp))

  `define bp_fe_cmd_attaboy_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
    (`bp_fe_cmd_operands_u_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp))

  `define bp_fe_cmd_itlb_fill_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
    (`bp_fe_cmd_operands_u_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp))

  `define bp_fe_cmd_icache_fill_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
    (`bp_fe_cmd_operands_u_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp))

  `define bp_pte_leaf_width(paddr_width_mp) \
    (paddr_width_mp - page_offset_width_gp + 8)

  `define bp_fe_cmd_itlb_fence_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
    (`bp_fe_cmd_operands_u_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp))

  /* Ensure all members of packed unions have the same size. If parameterized unions are desired,
   * examine this code carefully. Else, clients should not have to use these macros
   */
  `define bp_fe_fetch_width_no_padding(vaddr_width_mp, branch_metadata_fwd_width_mp) \
    (vaddr_width_mp + instr_width_gp + branch_metadata_fwd_width_mp)

  `define bp_fe_exception_width_no_padding(vaddr_width_mp) \
    (vaddr_width_mp + instr_width_gp + $bits(bp_fe_exception_code_e) + 1)

  `define bp_fe_cmd_pc_redirect_operands_width_no_padding(branch_metadata_fwd_width_mp) \
    ($bits(bp_fe_command_queue_subopcodes_e)                                            \
     + branch_metadata_fwd_width_mp + $bits(bp_fe_misprediction_reason_e) + 3)

  `define bp_fe_cmd_attaboy_width_no_padding(branch_metadata_fwd_width_mp) \
    (        1+branch_metadata_fwd_width_mp)

  `define bp_fe_cmd_itlb_fill_width_no_padding(vaddr_width_mp, paddr_width_mp) \
    (`bp_pte_leaf_width(paddr_width_mp)+instr_width_gp+fetch_ptr_p)

  `define bp_fe_cmd_icache_fill_width_no_padding \
    (instr_width_gp+fetch_ptr_p)

  `define bp_fe_cmd_itlb_fence_width_no_padding(asid_width_mp) \
    (asid_width_mp + 2)

  `define bp_fe_cmd_operands_u_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
    (1+`BSG_MAX(`bp_fe_cmd_pc_redirect_operands_width_no_padding(branch_metadata_fwd_width_mp)     \
                ,`BSG_MAX(`bp_fe_cmd_attaboy_width_no_padding(branch_metadata_fwd_width_mp)        \
                          ,`BSG_MAX(`bp_fe_cmd_itlb_fill_width_no_padding(vaddr_width_mp, paddr_width_mp) \
                                    ,`BSG_MAX(`bp_fe_cmd_itlb_fence_width_no_padding(asid_width_mp)\
                                             ,`bp_fe_cmd_icache_fill_width_no_padding              \
                                             )                                                     \
                                    )                                                              \
                          )                                                                        \
                )                                                                                  \
     )

  `define bp_fe_cmd_pc_redirect_operands_padding_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
    (`bp_fe_cmd_operands_u_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
     - `bp_fe_cmd_pc_redirect_operands_width_no_padding(branch_metadata_fwd_width_mp)                         \
     )

  `define bp_fe_cmd_attaboy_padding_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
    (`bp_fe_cmd_operands_u_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
     - `bp_fe_cmd_attaboy_width_no_padding(branch_metadata_fwd_width_mp)                                      \
     )

  `define bp_fe_cmd_itlb_fill_padding_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
    (`bp_fe_cmd_operands_u_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
     - `bp_fe_cmd_itlb_fill_width_no_padding(vaddr_width_mp, paddr_width_mp)                                   \
     )

  `define bp_fe_cmd_icache_fill_padding_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
    (`bp_fe_cmd_operands_u_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
     - `bp_fe_cmd_icache_fill_width_no_padding                                                              \
     )

  `define bp_fe_cmd_itlb_fence_padding_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
    (`bp_fe_cmd_operands_u_width(vaddr_width_mp, paddr_width_mp, asid_width_mp, branch_metadata_fwd_width_mp) \
     - `bp_fe_cmd_itlb_fence_width_no_padding(asid_width_mp)                                                  \
     )

`endif

