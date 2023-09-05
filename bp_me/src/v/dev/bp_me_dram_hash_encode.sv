/*
 * Name:
 *   bp_me_dram_hash_encode.sv
 *
 * Description:
 *   This module swizzles bits in an address, primarily to enable uniform access to L2/memory
 *   in a BlackParrot multicore.
 *
 *   IN:  [ taghi ][         taglo        ][     indexhi     ][ bank ][ slice ][ cce ][ block ]
 *   OUT: [ taghi ][ bank ][ slice ][ cce ][         taglo         ][     indexhi    ][ block ]
 *
 */

`include "bp_common_defines.svh"

module bp_me_dram_hash_encode
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   , localparam lg_num_cce_lp   = `BSG_SAFE_CLOG2(num_cce_p)
   , localparam lg_l2_slices_lp = `BSG_SAFE_CLOG2(l2_slices_p)
   , localparam lg_l2_banks_lp  = `BSG_SAFE_CLOG2(l2_banks_p)
   )
  (input [daddr_width_p-1:0]            daddr_i
   , output logic [daddr_width_p-1:0]   daddr_o
   , output logic [lg_num_cce_lp-1:0]   cce_o
   , output logic [lg_l2_slices_lp-1:0] slice_o
   , output logic [lg_l2_banks_lp-1:0]  bank_o
   );

  localparam l2_block_offset_width_lp = `BSG_SAFE_CLOG2(l2_block_width_p/8);
  localparam l2_tag_offset_width_lp   = `BSG_SAFE_CLOG2(l2_block_width_p*l2_sets_p/8);
  localparam l2_hash_offset_width_lp  = lg_num_cce_lp + lg_l2_slices_lp + lg_l2_banks_lp;
  localparam l2_indexhi_width_lp = `BSG_MAX(1, `BSG_SAFE_CLOG2(l2_sets_p) - l2_hash_offset_width_lp);
  localparam l2_taghi_width_lp = daddr_width_p - l2_tag_offset_width_lp - l2_hash_offset_width_lp;

  wire [l2_block_offset_width_lp-1:0] block = daddr_i[0+:l2_block_offset_width_lp];
  wire [lg_num_cce_lp-1:0]              cce = daddr_i[l2_block_offset_width_lp+:lg_num_cce_lp];
  wire [lg_l2_slices_lp-1:0]          slice = daddr_i[l2_block_offset_width_lp+lg_num_cce_lp+:lg_l2_slices_lp];
  wire [lg_l2_banks_lp-1:0]            bank = daddr_i[l2_block_offset_width_lp+lg_num_cce_lp+lg_l2_slices_lp+:lg_l2_banks_lp];

  wire [l2_indexhi_width_lp-1:0]    indexhi = daddr_i[l2_block_offset_width_lp+l2_hash_offset_width_lp+:l2_indexhi_width_lp];
  wire [l2_hash_offset_width_lp-1:0]  taglo = daddr_i[l2_tag_offset_width_lp+:l2_hash_offset_width_lp];
  wire [l2_taghi_width_lp-1:0]        taghi = daddr_i[daddr_width_p-1-:l2_taghi_width_lp];

  assign daddr_o = {taghi, bank, slice, cce, taglo, indexhi, block};
  assign cce_o   = (num_cce_p   > 1) ? cce   : '0;
  assign slice_o = (l2_slices_p > 1) ? slice : '0;
  assign bank_o  = (l2_banks_p  > 1) ? bank  : '0;

endmodule

