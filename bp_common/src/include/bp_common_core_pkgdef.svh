
`ifndef BP_COMMON_CORE_PKGDEF_SVH
`define BP_COMMON_CORE_PKGDEF_SVH

  /*
   * bp_fe_command_queue_opcodes_e defines the opcodes from backend to frontend in
   * the cases of an exception. bp_fe_command_queue_opcodes_e explains the reason
   * of why pc is redirected. Only e_op_pc_redirection contains possible at-fault
   * redirections
   * e_op_state_reset is used after the reset, which flushes all the states.
   * e_op_pc_redirection defines the changes of PC, which happens during the branches.
   * e_op_attaboy informs the frontend that the prediction is correct.
   * e_op_icache_fill_response happens when icache non-speculatively misses
   * e_op_icache_fence happens when there is flush in the icache.
   * e_op_itlb_fill_response happens when itlb populates translation and restarts fetching
   * e_op_itlb_fence issues a fence operation to itlb.
   */
  typedef enum logic [2:0]
  {
    e_op_state_reset           = 0
    ,e_op_pc_redirection       = 1
    ,e_op_attaboy              = 2
    ,e_op_icache_fill_response = 3
    ,e_op_icache_fence         = 4
    ,e_op_itlb_fill_response   = 5
    ,e_op_itlb_fence           = 6
    ,e_op_wait                 = 7
  } bp_fe_command_queue_opcodes_e;

  /*
   * bp_fe_misprediction_reason_e is the misprediction reason provided by the backend.
   */
  typedef enum logic [1:0]
  {
    e_not_a_branch           = 0
    ,e_incorrect_pred_taken  = 1
    ,e_incorrect_pred_ntaken = 2
  } bp_fe_misprediction_reason_e;

  /*
   * The exception code types.
   * e_itlb_miss is for an ITLB miss
   * e_instr_page_fault is for an access page fault
   * e_instr_access_fault is when the physical address is not allowed for the access type
   * e_icache_miss is for a nonspeculative I$ miss which needs to be confirmed by the backend
   */
  typedef enum logic [2:0]
  {
    e_itlb_miss            = 0
    ,e_instr_page_fault    = 1
    ,e_instr_access_fault  = 2
    ,e_icache_miss         = 3
    ,e_instr_fetch         = 4
  } bp_fe_queue_type_e;

  /*
   * bp_fe_command_queue_subopcodes_e defines the subopcodes in the case of pc_redirection in
   * bp_fe_command_queue_opcodes_e. It provides the reasons of why pc are redirected.
   * e_subop_uret,sret,mret are the returns from trap and contain the pc where it returns.
   * e_subop_interrupt is no-fault pc redirection.
   * e_subop_branch_mispredict is at-fault PC redirection.
   * e_subop_trap is at-fault PC redirection. It will changes the permission bits.
   * e_subop_context_switch is no-fault PC redirection. It redirect pc to a new address space.
   * e_subop_translation_switch is no-fault PC redirection resulting from translation mode changes
   * e_subop_resume is resuming from a no-fault PC redirect wait state.
   */
  typedef enum logic [2:0]
  {
    e_subop_eret
    ,e_subop_interrupt
    ,e_subop_branch_mispredict
    ,e_subop_trap
    ,e_subop_context_switch
    ,e_subop_translation_switch
    ,e_subop_resume
  } bp_fe_command_queue_subopcodes_e;

`endif

