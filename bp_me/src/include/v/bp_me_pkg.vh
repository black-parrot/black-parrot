/*
 * bp_me_pkg.vh
 *
 * Contains the interface structures used for communicating between the CCE and Memory.
 *
 */

package bp_me_pkg;

  import bp_common_pkg::*;

  `include "bp_mem_wormhole.vh"

  localparam mem_cmd_payload_mask_gp  = (1 << e_bedrock_mem_uc_wr) | (1 << e_bedrock_mem_wr);
  localparam mem_resp_payload_mask_gp = (1 << e_bedrock_mem_uc_rd) | (1 << e_bedrock_mem_rd);

endpackage : bp_me_pkg

