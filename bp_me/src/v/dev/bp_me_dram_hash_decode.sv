/*
 * Name:
 *   bp_me_dram_hash_decode.sv
 *
 * Description:
 *   This module reverses the bit swizzling applied by bp_me_dram_hash_encode.
 *
 *   IN:   [ tag ][ bank ][ slice ][ cce ][ set ][ block ]
 *   OUT:  [ tag ][ set ][ bank ][ slice ][ cce ][ block ]
 *
 */

`include "bp_common_defines.svh"

module bp_me_dram_hash_decode
 import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam lg_num_cce_lp   = `BSG_SAFE_CLOG2(num_cce_p)
   , localparam lg_l2_slices_lp = `BSG_SAFE_CLOG2(l2_slices_p)
   , localparam lg_l2_banks_lp  = `BSG_SAFE_CLOG2(l2_banks_p)
   , localparam lg_l2_sets_lp   = `BSG_SAFE_CLOG2(l2_sets_p)
   )
  (input [daddr_width_p-1:0]          daddr_i
   , output logic [daddr_width_p-1:0] daddr_o
   );

  // set, bank, slice, and cce index widths may be 0 (if there is only 1 cce, slice per cce,
  // bank per slice, or set per bank), which needs to be accounted for when extracting bits

  localparam l2_block_offset_width_lp = `BSG_SAFE_CLOG2(l2_block_width_p/8);
  localparam l2_set_index_width_lp = (l2_sets_p > 1) ? lg_l2_sets_lp : 0;
  localparam l2_bank_index_width_lp = (l2_banks_p > 1) ? lg_l2_banks_lp : 0;
  localparam l2_slice_index_width_lp = (l2_slices_p > 1) ? lg_l2_slices_lp : 0;
  localparam l2_cce_index_width_lp = (num_cce_p > 1) ? lg_num_cce_lp : 0;

  // compute offsets for each field in the IN address
  localparam l2_set_offset_lp   = l2_block_offset_width_lp;
  localparam l2_cce_offset_lp   = l2_set_offset_lp + l2_set_index_width_lp;
  localparam l2_slice_offset_lp = l2_cce_offset_lp + l2_cce_index_width_lp;
  localparam l2_bank_offset_lp  = l2_slice_offset_lp + l2_slice_index_width_lp;
  localparam l2_tag_offset_lp   = l2_bank_offset_lp + l2_bank_index_width_lp;

  // compute tag width (remaining high-order bits)
  localparam l2_tag_width_lp = daddr_width_p - l2_tag_offset_lp;

  // extract fields (use offset above to compute start bit, but extract bits ignoring if size of field is 0)
  wire [l2_block_offset_width_lp-1:0] block = daddr_i[0+:l2_block_offset_width_lp];
  wire [lg_l2_sets_lp-1:0]              set = daddr_i[l2_set_offset_lp+:lg_l2_sets_lp];
  wire [lg_num_cce_lp-1:0]              cce = daddr_i[l2_cce_offset_lp+:lg_num_cce_lp];
  wire [lg_l2_slices_lp-1:0]          slice = daddr_i[l2_slice_offset_lp+:lg_l2_slices_lp];
  wire [lg_l2_banks_lp-1:0]            bank = daddr_i[l2_bank_offset_lp+:lg_l2_banks_lp];
  wire [l2_tag_width_lp-1:0]            tag = daddr_i[l2_tag_offset_lp+:l2_tag_width_lp];

  // assemble the address
  // note: using concatentation and replication operators would be preferred here,
  // but Vivado (xsim) v2022.1 throws a fatal error when using them to assemble addr.
  logic [daddr_width_p-1:0] addr;
  assign addr[l2_tag_offset_lp+:l2_tag_width_lp] = tag;
  assign addr[0+:l2_block_offset_width_lp]       = block;
  if (num_cce_p > 1)   assign addr[l2_cce_offset_lp+:lg_num_cce_lp]      = cce;
  if (l2_slices_p > 1) assign addr[l2_slice_offset_lp+:lg_l2_slices_lp]  = slice;
  if (l2_banks_p > 1)  assign addr[l2_bank_offset_lp+:lg_l2_banks_lp]    = bank;
  if (l2_sets_p > 1)   assign addr[l2_set_offset_lp+:lg_l2_sets_lp]      = set;

  assign daddr_o = addr;

endmodule

