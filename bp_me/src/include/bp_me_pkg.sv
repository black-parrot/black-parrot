/*
 * bp_me_pkg.svh
 *
 * Contains the interface structures used for communicating between the CCE and Memory.
 *
 */

package bp_me_pkg;

  import bp_common_pkg::*;

  localparam mem_cmd_payload_mask_gp  = (1 << e_bedrock_mem_uc_wr) | (1 << e_bedrock_mem_wr) | (1 << e_bedrock_mem_amo);
  localparam mem_resp_payload_mask_gp = (1 << e_bedrock_mem_uc_rd) | (1 << e_bedrock_mem_rd) | (1 << e_bedrock_mem_amo);

  `include "bp_me_cce_inst_pkgdef.svh"

endpackage

