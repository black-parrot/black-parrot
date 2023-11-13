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
`include "bp_me_defines.svh"

module bp_me_dram_hash_encode
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam lg_num_cce_lp   = `BSG_SAFE_CLOG2(num_cce_p)
   , localparam lg_l2_slices_lp = `BSG_SAFE_CLOG2(l2_slices_p)
   , localparam lg_l2_banks_lp  = `BSG_SAFE_CLOG2(l2_banks_p)
   , localparam lg_l2_sets_lp   = `BSG_SAFE_CLOG2(l2_sets_p)
   , localparam lg_l2_assoc_lp  = `BSG_SAFE_CLOG2(l2_assoc_p)
   )
  (input [paddr_width_p-1:0]            paddr_i
   , input [bedrock_fill_width_p-1:0]   data_i

   , output logic                       dram_o
   , output logic [daddr_width_p-1:0]   daddr_o
   , output logic [lg_l2_slices_lp-1:0] slice_o
   , output logic [lg_l2_banks_lp-1:0]  bank_o
   , output logic [l2_data_width_p-1:0] data_o
   );

  localparam l2_block_offset_width_lp = `BSG_SAFE_CLOG2(l2_block_width_p/8);
  localparam l2_tag_offset_width_lp   = `BSG_SAFE_CLOG2(l2_block_width_p*l2_sets_p/8);
  localparam l2_hash_offset_width_lp  = lg_num_cce_lp + lg_l2_slices_lp + lg_l2_banks_lp;
  localparam l2_indexhi_width_lp = `BSG_MAX(1, `BSG_SAFE_CLOG2(l2_sets_p) - l2_hash_offset_width_lp);
  localparam l2_taghi_width_lp = daddr_width_p - l2_tag_offset_width_lp - l2_hash_offset_width_lp;
  bp_me_l2_csr_addr_s tag_addr_li;
  assign tag_addr_li = paddr_i;

  wire is_dram_addr = paddr_i >= dram_base_addr_gp;
  wire is_csr_addr  = paddr_i  < dram_base_addr_gp;
  wire is_tag_op  = is_csr_addr & paddr_i[0+:dev_addr_width_gp] inside {cache_tagop_match_addr_gp};
  wire is_lock_op = is_csr_addr & paddr_i[0+:dev_addr_width_gp] inside {cache_alock_match_addr_gp};
  wire is_addr_op = is_csr_addr & paddr_i[0+:dev_addr_width_gp] inside {cache_addrop_match_addr_gp};
  wire [daddr_width_p-1:0] tag_addr = {tag_addr_li.way, tag_addr_li.index} << l2_block_offset_width_lp;

  wire [daddr_width_p-1:0] daddr = is_tag_op ? tag_addr : is_addr_op ? data_i : paddr_i;
  wire [l2_block_offset_width_lp-1:0] block = daddr[0+:l2_block_offset_width_lp];
  wire [lg_num_cce_lp-1:0]              cce = daddr[l2_block_offset_width_lp+:lg_num_cce_lp];
  wire [lg_l2_slices_lp-1:0]          slice = daddr[l2_block_offset_width_lp+lg_num_cce_lp+:lg_l2_slices_lp];
  wire [lg_l2_banks_lp-1:0]            bank = daddr[l2_block_offset_width_lp+lg_num_cce_lp+lg_l2_slices_lp+:lg_l2_banks_lp];
  wire [l2_indexhi_width_lp-1:0]    indexhi = daddr[l2_block_offset_width_lp+l2_hash_offset_width_lp+:l2_indexhi_width_lp];
  wire [l2_hash_offset_width_lp-1:0]  taglo = daddr[l2_tag_offset_width_lp+:l2_hash_offset_width_lp];
  wire [l2_taghi_width_lp-1:0]        taghi = daddr[daddr_width_p-1-:l2_taghi_width_lp];
  wire [daddr_width_p-1:0]             addr = {taghi, bank, slice, cce, taglo, indexhi, block};

  wire [dev_id_width_gp-1:0] tag_dev   = paddr_i[dev_addr_width_gp+:dev_id_width_gp];
  wire [lg_l2_slices_lp-1:0] tag_slice = is_tag_op ? (tag_dev - cache_dev_gp) : slice;

  assign dram_o  = is_dram_addr;
  assign daddr_o =                     is_tag_op ? tag_addr          : addr          ;
  assign slice_o = (l2_slices_p > 1) ? is_tag_op ? tag_slice         : slice     : '0;
  assign bank_o  = (l2_banks_p  > 1) ? is_tag_op ? tag_addr_li.bank  : bank      : '0;
  assign index_o = (l2_sets_p   > 1) ? is_tag_op ? tag_addr_li.index : '0        : '0;
  assign way_o   = (l2_assoc_p  > 1) ? is_tag_op ? tag_addr_li.way   : '0        : '0;
  assign data_o  = data_i;

endmodule

