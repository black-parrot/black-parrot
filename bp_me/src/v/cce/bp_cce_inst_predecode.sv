/**
 *
 * Name:
 *   bp_cce_inst_predecode.sv
 *
 * Description:
 *   The pre-decoder examines the branch and predict bits from the instruction, extracts the
 *   branch target from the instruction, and then outputs the next fetch PC.
 *   The next fetch PC is either current fetch PC + 1 or the branch target.
 *
 *   The pc_i signal comes directly from the fetch PC register (which has the same value as
 *   the registered address in the instruction RAM), and the instruction comes from the read of
 *   the instruction RAM.
 *
 *   The Fetch PC register, through the instruction RAM read, through pre-decode, and then
 *   through muxes to the input of the Fetch PC register for the next cycle is a likely critical
 *   path in the CCE.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_inst_predecode
  import bp_me_pkg::*;
  #(parameter `BSG_INV_PARAM(width_p))
  (input bp_cce_inst_s                              inst_i
   , input [width_p-1:0]                            pc_i
   , output logic [width_p-1:0]                     predicted_next_pc_o
  );

  // parameter checks
  if (width_p > `bp_cce_inst_addr_width)
    $error("Desired address width is larger than address width used in instruction encoding");

  wire [width_p-1:0] pc_plus_one = width_p'(pc_i + 'd1);
  wire [width_p-1:0] branch_target = inst_i.type_u.btype.target[0+:width_p];
  wire predict_taken = (inst_i.branch & inst_i.predict_taken);

  assign predicted_next_pc_o = predict_taken ? branch_target : pc_plus_one;

endmodule

`BSG_ABSTRACT_MODULE(bp_cce_inst_predecode)
