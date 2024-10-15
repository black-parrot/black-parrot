/**
 *
 * Name:
 *   bp_me_addr_to_cce_wg_id.sv
 *
 * Description:
 *   This module converts a physical address to a cce id and waygroup id.
 *   Blocks are striped across CCEs.
 *
 *   address = [ tag |       set       | block offset ]
 *   address = [ tag | way group | cce | block offset ]
 *
 *   Assumptions:
 *   - number of CCE in system is a power-of-two
 *   - number of way groups (in system and per-CCE) is a power-of-two
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_addr_to_cce_wg_id
  import bp_common_pkg::*;
  #(parameter `BSG_INV_PARAM(paddr_width_p)
    // number of way groups managed by one CCE
    , parameter `BSG_INV_PARAM(num_way_groups_p)
    // total number of CCE in system
    , parameter `BSG_INV_PARAM(num_cce_p)
    , parameter `BSG_INV_PARAM(block_width_p)
    // Derived parameters
    , localparam lg_num_way_groups_lp = `BSG_SAFE_CLOG2(num_way_groups_p)
    , localparam lg_num_cce_lp        = `BSG_SAFE_CLOG2(num_cce_p)
  )
  (input [paddr_width_p-1:0]                    addr_i
   , output logic [lg_num_cce_lp-1:0]           cce_id_o
   , output logic [lg_num_way_groups_lp-1:0]    wg_id_o
  );

  if (!`BSG_IS_POW2(num_way_groups_p))
    $error("Error: number of way groups per CCE must be a power-of-two");

  if (!`BSG_IS_POW2(num_cce_p))
    $error("Error: number of CCE must be a power-of-two");

  localparam block_size_in_bytes_lp = (block_width_p/8);
  localparam lg_block_size_in_bytes_lp = `BSG_SAFE_CLOG2(block_size_in_bytes_lp);
  localparam cce_id_offset_lp = lg_block_size_in_bytes_lp;
  localparam wg_id_offset_lp = cce_id_offset_lp
                               + ((num_cce_p > 1) ? lg_num_cce_lp : 0);

  assign cce_id_o = (num_cce_p > 1)
                    ? addr_i[cce_id_offset_lp+:lg_num_cce_lp]
                    : '0;
  assign wg_id_o = addr_i[wg_id_offset_lp+:lg_num_way_groups_lp];

endmodule
