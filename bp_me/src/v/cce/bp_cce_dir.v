/**
 * bp_cce_dir.v
 *
 * The directory stores the coherence state and tags for all cache blocks tracked by
 * a CCE. The directory supports a small set of operations such as reading and writing
 * pending bits for a way-group, reading a way-group or entry, and writing an entry's
 * coherence state and tag.
 *
 * The way-group memory in the directory is a synchronous read 1RW memories.
 * The pending bits are stored in flops.
 *
 * All writes take 1 cycle
 * RDW and RDE instructions present valid data in the next cycle (synchronous reads)
 * RDP presents valid data in same cycle (asynchronous reads)
 *
 */

`include "bp_common_me_if.vh"
`include "bp_cce_inst_pkg.v"

module bp_cce_dir
  import bp_cce_inst_pkg::*;
  #(parameter num_way_groups_p="inv"
    ,parameter num_lce_p="inv"
    ,parameter lce_assoc_p="inv"
    ,parameter tag_width_p="inv"
    ,parameter lg_num_way_groups_lp=`BSG_SAFE_CLOG2(num_way_groups_p)
    ,parameter lg_num_lce_lp=`BSG_SAFE_CLOG2(num_lce_p)
    ,parameter lg_lce_assoc_lp=`BSG_SAFE_CLOG2(lce_assoc_p)
    ,parameter entry_width_lp=tag_width_p+`bp_cce_coh_bits
    ,parameter tag_set_width_lp=(entry_width_lp*lce_assoc_p)
    ,parameter way_group_width_lp=(tag_set_width_lp*num_lce_p)
    ,parameter harden_p=0
  )
  (
    input                                    clk_i
    ,input                                   reset_i

    ,input [lg_num_way_groups_lp-1:0]        way_group_i
    ,input [lg_num_lce_lp-1:0]               lce_i
    ,input [lg_lce_assoc_lp-1:0]             way_i
    ,input [`bp_cce_inst_minor_op_width-1:0] r_cmd_i
    ,input                                   r_v_i

    ,input [tag_width_p-1:0]                 tag_i
    ,input [`bp_cce_coh_bits-1:0]            coh_state_i
    ,input                                   pending_i
    ,input [`bp_cce_inst_minor_op_width-1:0] w_cmd_i
    ,input                                   w_v_i

    ,output logic                            pending_o
    ,output logic                            pending_v_o
    ,output logic [tag_width_p-1:0]          tag_o
    ,output logic [`bp_cce_coh_bits-1:0]     coh_state_o
    ,output logic                            entry_v_o
    ,output logic [way_group_width_lp-1:0]   way_group_o
    ,output logic                            way_group_v_o
  );

  // pending bits
  logic [num_way_groups_p-1:0] pending_bits_r;
  logic pending_w_v, pending_r_v;
  assign pending_w_v = w_v_i & (w_cmd_i == e_wdp_op);
  assign pending_r_v = r_v_i & (r_cmd_i == e_rdp_op);

  always_ff @(posedge clk_i) begin
    if (pending_w_v) begin
      pending_bits_r[way_group_i] <= pending_i;
    end
  end

  assign pending_o = pending_bits_r[way_group_i];
  assign pending_v_o = pending_r_v;

  // way-group (tag and state) maskable write ram
  logic wg_ram_w_v, wg_ram_r_v;
  logic wg_ram_v;
  logic [lg_num_way_groups_lp-1:0] wg_ram_addr;
  logic [way_group_width_lp-1:0] wg_ram_w_mask;
  logic [way_group_width_lp-1:0] wg_ram_w_data;

  assign wg_ram_r_v = r_v_i & ((r_cmd_i == e_rdw_op) | (r_cmd_i == e_rde_op));
  assign wg_ram_w_v = w_v_i & ((w_cmd_i == e_wde_op) | (w_cmd_i == e_wds_op));
  assign wg_ram_v = (wg_ram_r_v | wg_ram_w_v);

  assign wg_ram_addr = wg_ram_v ? way_group_i : 'X;

  assign wg_ram_w_mask =
    w_cmd_i == e_wde_op ? {{(way_group_width_lp-entry_width_lp){1'b0}},{entry_width_lp{1'b1}}} << (lce_i*tag_set_width_lp + way_i*entry_width_lp) :
    w_cmd_i == e_wds_op ? {{(way_group_width_lp-`bp_cce_coh_bits){1'b0}},{`bp_cce_coh_bits{1'b1}}} << (lce_i*tag_set_width_lp + way_i*entry_width_lp) :
    '0;

  assign wg_ram_w_data = {{(way_group_width_lp-entry_width_lp){1'b0}},{tag_i, coh_state_i}} << (lce_i*tag_set_width_lp + way_i*entry_width_lp);

  // Reads are synchronous, with the address latched in the current cycle, and data available next
  // Writes take 1 cycle
  bsg_mem_1rw_sync_mask_write_bit_synth
    #(.width_p(way_group_width_lp)
      ,.els_p(num_way_groups_p)
     )
     wg_ram
     (
      .clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.w_i(wg_ram_w_v)
      ,.w_mask_i(wg_ram_w_mask)
      ,.addr_i(wg_ram_addr)
      ,.data_i(wg_ram_w_data)
      ,.v_i(wg_ram_v)
      ,.data_o(way_group_o)
     );

  // read valid registers
  logic entry_v_r, wg_v_r;
  always_ff @(posedge clk_i) begin
    entry_v_r <= '0;
    wg_v_r <= '0;
    if (r_v_i & (r_cmd_i == e_rde_op)) begin
      entry_v_r <= 1'b1;
    end
    if (wg_ram_r_v) begin
      wg_v_r <= 1'b1;
    end
  end

  logic [tag_set_width_lp-1:0] tag_set;
  logic [entry_width_lp-1:0] entry;

  assign tag_set = way_group_o[lce_i*tag_set_width_lp +: tag_set_width_lp];
  assign entry = tag_set[way_i*entry_width_lp +: entry_width_lp];

  assign tag_o = entry[`bp_cce_coh_bits +: tag_width_p];
  assign coh_state_o = entry[0 +: `bp_cce_coh_bits];

  assign entry_v_o = entry_v_r;
  assign way_group_v_o = wg_v_r;

endmodule
