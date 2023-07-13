/**
 *
 * Name:
 *   bp_cce_inst_stall.sv
 *
 * Description:
 *   The stall unit collects the current instruction and status of other functional units to
 *   determine whether or not a stall must occur.
 *
 *   A stall prevents any changes to architectural state in the cycle asserted, and causes the
 *   current instruction to be replayed next cycle.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_inst_stall
  import bp_me_pkg::*;
  #()
  (input bp_cce_inst_decoded_s                   decoded_inst_i

   // input queue valid signals
   , input                                       lce_req_v_i
   , input                                       lce_resp_v_i
   , input                                       mem_rev_v_i
   , input                                       pending_v_i

   // output queue valid&ready signals
   , input                                       lce_cmd_yumi_i

   , input                                       mem_credits_empty_i

   // Messague Unit resource busy signals
   // message unit is busy doing something - block all ucode interactions
   , input                                       msg_busy_i
   , input                                       msg_pending_w_busy_i
   , input                                       msg_lce_cmd_busy_i
   , input                                       msg_lce_resp_busy_i
   , input                                       msg_mem_rev_busy_i
   , input                                       msg_spec_r_busy_i
   , input                                       msg_dir_w_busy_i
   , input                                       msg_mem_fwd_stall_i

   // Directory busy (e.g., processing read)
   , input                                       dir_busy_i

   // Stall outputs
   , output logic                                stall_o
  );

  wire [$bits(bp_cce_inst_src_q_e)-1:0] wfq_v_vec = {lce_req_v_i, lce_resp_v_i, mem_rev_v_i, pending_v_i};
  wire [$bits(bp_cce_inst_src_q_e)-1:0] wfq_mask = decoded_inst_i.imm[0+:$bits(bp_cce_inst_src_q_e)];

  always_comb begin
    stall_o = 1'b0;

    // Microcode instruction stalls - resource not ready

    // Message receive
    // Handshake is v->yumi for headers from fifo
    stall_o |= (decoded_inst_i.lce_req_yumi & ~lce_req_v_i);
    stall_o |= (decoded_inst_i.lce_resp_yumi & ~lce_resp_v_i);
    stall_o |= (decoded_inst_i.mem_rev_yumi & ~mem_rev_v_i);
    stall_o |= (decoded_inst_i.pending_yumi & ~pending_v_i);

    // Pop Header
    stall_o |= (decoded_inst_i.poph & (~lce_req_v_i & (decoded_inst_i.popq_qsel == e_src_q_sel_lce_req)));
    stall_o |= (decoded_inst_i.poph & (~lce_resp_v_i & (decoded_inst_i.popq_qsel == e_src_q_sel_lce_resp)));
    stall_o |= (decoded_inst_i.poph & (~mem_rev_v_i & (decoded_inst_i.popq_qsel == e_src_q_sel_mem_rev)));

    // Pop Data - TODO: not fully implemented
    stall_o |= (decoded_inst_i.popd & (~lce_req_v_i & (decoded_inst_i.popq_qsel == e_src_q_sel_lce_req)));
    stall_o |= (decoded_inst_i.popd & (~lce_resp_v_i & (decoded_inst_i.popq_qsel == e_src_q_sel_lce_resp)));
    stall_o |= (decoded_inst_i.popd & (~mem_rev_v_i & (decoded_inst_i.popq_qsel == e_src_q_sel_mem_rev)));

    // Message send
    // Handshake is r&v
    stall_o |= (decoded_inst_i.lce_cmd_v & ~lce_cmd_yumi_i);
    // memory command stall is indicated directly by a signal from message unit
    stall_o |= (decoded_inst_i.mem_fwd_v & msg_mem_fwd_stall_i);
    // sending a memory command requires a memory credit
    stall_o |= (decoded_inst_i.mem_fwd_v & mem_credits_empty_i);

    // Wait for queue operation
    stall_o |= (decoded_inst_i.wfq_v & ~(|(wfq_mask & wfq_v_vec)));


    // Functional Unit induced stalls

    // Directory is busy after a read - be safe and block execution until read is done
    stall_o |= dir_busy_i;

    // Message unit is stalling all ucode, i.e., invalidation instruction is executing
    stall_o |= msg_busy_i;

    // Message Unit Structural Hazards
    stall_o |= (decoded_inst_i.pending_w_v & msg_pending_w_busy_i);
    stall_o |= (decoded_inst_i.lce_cmd_v & msg_lce_cmd_busy_i);
    stall_o |= (decoded_inst_i.lce_resp_yumi & msg_lce_resp_busy_i);
    stall_o |= (decoded_inst_i.mem_rev_yumi & msg_mem_rev_busy_i);
    stall_o |= (decoded_inst_i.spec_r_v & msg_spec_r_busy_i);
    stall_o |= (decoded_inst_i.dir_w_v & msg_dir_w_busy_i);
    stall_o |= (decoded_inst_i.dir_r_v & msg_dir_w_busy_i);

    // only stall on valid instruction
    stall_o &= decoded_inst_i.v;

  end

endmodule
