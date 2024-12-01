/**
 *
 * Name:
 *   bp_cce_hybrid_inst_stall.sv
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

module bp_cce_hybrid_inst_stall
  import bp_me_pkg::*;
  #()
  (input bp_cce_inst_decoded_s                   decoded_inst_i

   // input queue valid signals
   , input                                       lce_req_v_i

   // Stall outputs
   , output logic                                stall_o
  );

  wire [$bits(bp_cce_inst_src_q_e)-1:0] wfq_v_vec = {lce_req_v_i, 3'b0};
  wire [$bits(bp_cce_inst_src_q_e)-1:0] wfq_mask = decoded_inst_i.imm[0+:$bits(bp_cce_inst_src_q_e)];

  always_comb begin
    stall_o = 1'b0;

    // Microcode instruction stalls - resource not ready

    // Message receive
    // Handshake is v->yumi for headers from fifo
    stall_o |= (decoded_inst_i.lce_req_yumi & ~lce_req_v_i);

    // Pop Header
    stall_o |= (decoded_inst_i.poph & (~lce_req_v_i & (decoded_inst_i.popq_qsel == e_src_q_sel_lce_req)));

    // Wait for queue operation
    stall_o |= (decoded_inst_i.wfq_v & ~(|(wfq_mask & wfq_v_vec)));

    // only stall on valid instruction
    stall_o &= decoded_inst_i.v;

  end

endmodule

`BSG_ABSTRACT_MODULE(bp_cce_hybrid_inst_stall)
