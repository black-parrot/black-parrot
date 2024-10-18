/*
 * Name:
 *   bp_me_dram_hash_encode.sv
 *
 * Description:
 *   This module swizzles bits in an address, primarily to enable uniform access to L2/memory
 *   in a BlackParrot multicore.
 *
 *   ADDR: [             block number           ][ block ]
 *   IN:   [ tag ][ set ][ bank ][ slice ][ cce ][ block ]
 *   OUT:  [ tag ][ bank ][ slice ][ cce ][ set ][ block ]
 *
 *   Blocks are striped across CCEs by bsg_hash_bank using least-significant log2(num_cce_p) bits
 *   from the block number field. Blocks are then distributed across slices and across banks at
 *   the selected L2.
 *
 *   This hashing assumes the number of slices, banks, and sets are powers of two. The number
 *   of CCEs (L2s) must be a value supported by bsg_hash_bank.
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
   )
  (input [paddr_width_p-1:0]            paddr_i
   , input [bedrock_fill_width_p-1:0]   data_i

   , output logic                       dram_o
   , output logic [daddr_width_p-1:0]   daddr_o
   , output logic [lg_l2_slices_lp-1:0] slice_o
   , output logic [lg_l2_banks_lp-1:0]  bank_o
   , output logic [l2_data_width_p-1:0] data_o
   );

  bp_me_l2_csr_addr_s tag_addr_li;
  assign tag_addr_li = paddr_i;

  wire is_dram_addr = paddr_i >= dram_base_addr_gp;
  wire is_csr_addr  = paddr_i  < dram_base_addr_gp;
  wire is_tag_op  = is_csr_addr & paddr_i[0+:dev_addr_width_gp] inside {cache_tagop_match_addr_gp};
  wire is_lock_op = is_csr_addr & paddr_i[0+:dev_addr_width_gp] inside {cache_alock_match_addr_gp};
  wire is_addr_op = is_csr_addr & paddr_i[0+:dev_addr_width_gp] inside {cache_addrop_match_addr_gp};

  // set, bank, slice, and cce index widths may be 0 (if there is only 1 cce, slice per cce,
  // bank per slice, or set per bank), which needs to be accounted for when extracting bits

  localparam l2_block_offset_width_lp = `BSG_SAFE_CLOG2(l2_block_width_p/8);
  localparam l2_set_index_width_lp = (l2_sets_p > 1) ? lg_l2_sets_lp : 0;
  localparam l2_bank_index_width_lp = (l2_banks_p > 1) ? lg_l2_banks_lp : 0;
  localparam l2_slice_index_width_lp = (l2_slices_p > 1) ? lg_l2_slices_lp : 0;
  localparam l2_cce_index_width_lp = (num_cce_p > 1) ? lg_num_cce_lp : 0;

  // compute offsets for each field in the IN address
  localparam l2_cce_offset_lp   = l2_block_offset_width_lp;
  localparam l2_slice_offset_lp = l2_cce_offset_lp + l2_cce_index_width_lp;
  localparam l2_bank_offset_lp  = l2_slice_offset_lp + l2_slice_index_width_lp;
  localparam l2_set_offset_lp   = l2_bank_offset_lp + l2_bank_index_width_lp;
  localparam l2_tag_offset_lp   = l2_set_offset_lp + l2_set_index_width_lp;

  // compute tag width (remaining high-order bits)
  localparam l2_tag_width_lp = daddr_width_p - l2_tag_offset_lp;

  wire [daddr_width_p-1:0] tag_addr = {tag_addr_li.way, tag_addr_li.index} << l2_block_offset_width_lp;
  wire [daddr_width_p-1:0] daddr = is_tag_op ? tag_addr : is_addr_op ? data_i : paddr_i;

  // extract fields (use offset above to compute start bit, but extract bits ignoring if size of field is 0)
  wire [l2_block_offset_width_lp-1:0] block = daddr[0+:l2_block_offset_width_lp];
  wire [lg_num_cce_lp-1:0]              cce = daddr[l2_cce_offset_lp+:lg_num_cce_lp];
  wire [lg_l2_slices_lp-1:0]          slice = daddr[l2_slice_offset_lp+:lg_l2_slices_lp];
  wire [lg_l2_banks_lp-1:0]            bank = daddr[l2_bank_offset_lp+:lg_l2_banks_lp];
  wire [lg_l2_sets_lp-1:0]              set = daddr[l2_set_offset_lp+:lg_l2_sets_lp];
  wire [l2_tag_width_lp-1:0]            tag = daddr[l2_tag_offset_lp+:l2_tag_width_lp];

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

  wire [dev_id_width_gp-1:0] tag_dev   = paddr_i[dev_addr_width_gp+:dev_id_width_gp];
  wire [lg_l2_slices_lp-1:0] tag_slice = tag_dev - cache_dev_gp;

  assign dram_o  = is_dram_addr;
  assign daddr_o =                     is_tag_op ? tag_addr          : addr          ;
  assign slice_o = (l2_slices_p > 1) ? is_tag_op ? tag_slice         : slice     : '0;
  assign bank_o  = (l2_banks_p  > 1) ? is_tag_op ? tag_addr_li.bank  : bank      : '0;
  assign data_o  = data_i;

endmodule

