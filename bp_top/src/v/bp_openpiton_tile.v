
module bp_openpiton_tile
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_be_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_cfg_link_pkg::*;
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
   `declare_bp_proc_params(cfg_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)

   , parameter calc_trace_p = 0
   , parameter cce_trace_p  = 0

   // Wormhole parameters
   , localparam dims_lp = 1
   , localparam int cord_markers_pos_lp[dims_lp:0] = '{noc_cord_width_p, 0}
   , localparam cord_width_lp = cord_markers_pos_lp[dims_lp]
   , localparam dirs_lp = dims_lp*2+1
   , localparam bit [1:0][dirs_lp-1:0][dirs_lp-1:0] routing_matrix_lp = StrictX

   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(noc_width_p)
   )
  (input                                       clk_i
   , input                                     reset_i

   , input [num_core_p-1:0][cord_width_lp-1:0] tile_cord_i
   , input [cord_width_lp-1:0]                 dram_cord_i
   , input [cord_width_lp-1:0]                 clint_cord_i
   , input [cord_width_lp-1:0]                 openpiton_cord_i

   // BP DRAM
   // TODO: Attach internally
   , input  [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o

   , input  [bsg_ready_and_link_sif_width_lp-1:0]  resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0]  resp_link_o

   // OpenPiton Bus
   // BP -> L1.5
   , output [cce_mem_cmd_width_lp-1:0]               op_mem_cmd_o
   , output                                          op_mem_cmd_v_o
   , input                                           op_mem_cmd_yumi_i

   , output [cce_mem_data_cmd_width_lp-1:0]          op_mem_data_cmd_o
   , output                                          op_mem_data_cmd_v_o
   , input                                           op_mem_data_cmd_yumi_i
   // L1.5 -> BP
   , input [mem_cce_resp_width_lp-1:0]               op_mem_resp_i
   , input                                           op_mem_resp_v_i
   , output                                          op_mem_resp_ready_o

   , input [mem_cce_data_resp_width_lp-1:0]          op_mem_data_resp_i
   , input                                           op_mem_data_resp_v_i
   , output                                          op_mem_data_resp_ready_o
   );

`declare_bsg_ready_and_link_sif_s(noc_width_p, bsg_ready_and_link_sif_s);
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p, mem_payload_width_p)

bsg_ready_and_link_sif_s chip_cmd_link_li, chip_cmd_link_lo;
bsg_ready_and_link_sif_s chip_resp_link_li, chip_resp_link_lo;

bsg_ready_and_link_sif_s op_master_link_li, op_master_link_lo;
bsg_ready_and_link_sif_s op_client_link_li, op_client_link_lo;

bsg_ready_and_link_sif_s [E:P] cmd_link_li, cmd_link_lo;
bsg_ready_and_link_sif_s [E:P] resp_link_li, resp_link_lo;

bp_cce_mem_cmd_s       op_mem_cmd_lo;
logic                  op_mem_cmd_v_lo, op_mem_cmd_yumi_li;
bp_cce_mem_data_cmd_s  op_mem_data_cmd_lo;
logic                  op_mem_data_cmd_v_lo, op_mem_data_cmd_yumi_li;
bp_mem_cce_resp_s      op_mem_resp_li;
logic                  op_mem_resp_v_li, op_mem_resp_ready_lo;
bp_mem_cce_data_resp_s op_mem_data_resp_li;
logic                  op_mem_data_resp_v_li, op_mem_data_resp_ready_lo;

bp_cce_mem_cmd_s       op_mem_cmd_li;
logic                  op_mem_cmd_v_li, op_mem_cmd_yumi_lo;
bp_cce_mem_data_cmd_s  op_mem_data_cmd_li;
logic                  op_mem_data_cmd_v_li, op_mem_data_cmd_yumi_lo;
bp_mem_cce_resp_s      op_mem_resp_lo;
logic                  op_mem_resp_v_lo, op_mem_resp_ready_li;
bp_mem_cce_data_resp_s op_mem_data_resp_lo;
logic                  op_mem_data_resp_v_lo, op_mem_data_resp_ready_li;

bp_chip
 #(.cfg_p(cfg_p)
   ,.calc_trace_p(calc_trace_p)
   ,.cce_trace_p(cce_trace_p)
   )
 chip
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.tile_cord_i(tile_cord_i)
   ,.dram_cord_i(dram_cord_i)
   ,.clint_cord_i(clint_cord_i)
   ,.openpiton_cord_i(openpiton_cord_i)

   ,.cmd_link_i(chip_cmd_link_li)
   ,.cmd_link_o(chip_cmd_link_lo)

   ,.resp_link_i(chip_resp_link_li)
   ,.resp_link_o(chip_resp_link_lo)
   );

bsg_wormhole_router_generalized
 #(.flit_width_p(noc_width_p)
   ,.dims_p(dims_lp)
   ,.cord_markers_pos_p(cord_markers_pos_lp)
   ,.routing_matrix_p(routing_matrix_lp)
   ,.len_width_p(noc_len_width_p)
   )
 cmd_router
 (.clk_i(clk_i)
  ,.reset_i(reset_i)
  ,.my_cord_i(openpiton_cord_i)
  ,.link_i(cmd_link_li)
  ,.link_o(cmd_link_lo)
  );

assign cmd_link_li[W] = chip_cmd_link_lo;
assign cmd_link_li[E] = cmd_link_i;

assign chip_cmd_link_li = cmd_link_lo[W];
assign cmd_link_o = cmd_link_lo[E];

bsg_wormhole_router_generalized
 #(.flit_width_p(noc_width_p)
   ,.dims_p(dims_lp)
   ,.cord_markers_pos_p(cord_markers_pos_lp)
   ,.routing_matrix_p(routing_matrix_lp)
   ,.len_width_p(noc_len_width_p)
   )
 resp_router
  (.clk_i(clk_i)
   ,.reset_i(reset_i)
   ,.my_cord_i(openpiton_cord_i)
   ,.link_i(resp_link_li)
   ,.link_o(resp_link_lo)
   );

assign resp_link_li[W] = chip_resp_link_lo;
assign resp_link_li[E] = resp_link_i;

assign chip_resp_link_li = resp_link_lo[W];
assign resp_link_o = resp_link_lo[E];

logic [noc_cord_width_p-1:0] cmd_dest_cord_lo;
bp_addr_map
 #(.cfg_p(cfg_p))
 cmd_map
  (.paddr_i(op_mem_cmd_lo.addr)

  ,.clint_cord_i(clint_cord_i)
  ,.dram_cord_i(dram_cord_i)
  ,.openpiton_cord_i(openpiton_cord_i)

  ,.dest_cord_o(cmd_dest_cord_lo)
  );

logic [noc_cord_width_p-1:0] data_cmd_dest_cord_lo;
bp_addr_map
 #(.cfg_p(cfg_p))
 data_cmd_map
  (.paddr_i(op_mem_data_cmd_lo.addr)
   ,.clint_cord_i(clint_cord_i)
   ,.dram_cord_i(dram_cord_i)
   ,.openpiton_cord_i(openpiton_cord_i)

   ,.dest_cord_o(data_cmd_dest_cord_lo)
   );

bp_me_cce_to_wormhole_link_master
 #(.cfg_p(cfg_p))
 master_link
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_i(op_mem_cmd_lo)
   ,.mem_cmd_v_i(op_mem_cmd_v_lo)
   ,.mem_cmd_yumi_o(op_mem_cmd_yumi_li)

   ,.mem_data_cmd_i(op_mem_data_cmd_lo)
   ,.mem_data_cmd_v_i(op_mem_data_cmd_v_lo)
   ,.mem_data_cmd_yumi_o(op_mem_data_cmd_yumi_li)

   ,.mem_resp_o(op_mem_resp_li)
   ,.mem_resp_v_o(op_mem_resp_v_li)
   ,.mem_resp_ready_i(op_mem_resp_ready_lo)

   ,.mem_data_resp_o(op_mem_data_resp_li)
   ,.mem_data_resp_v_o(op_mem_data_resp_v_li)
   ,.mem_data_resp_ready_i(op_mem_data_resp_ready_lo)

   ,.my_cord_i(openpiton_cord_i)
   ,.mem_cmd_dest_cord_i(cmd_dest_cord_lo)
   ,.mem_data_cmd_dest_cord_i(data_cmd_dest_cord_lo)

   ,.link_i(op_master_link_li)
   ,.link_o(op_master_link_lo)
   );

bp_me_cce_to_wormhole_link_client
 #(.cfg_p(cfg_p))
 client_link
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_o(op_mem_cmd_o)
   ,.mem_cmd_v_o(op_mem_cmd_v_o)
   ,.mem_cmd_yumi_i(op_mem_cmd_yumi_i)

   ,.mem_data_cmd_o(op_mem_data_cmd_o)
   ,.mem_data_cmd_v_o(op_mem_data_cmd_v_o)
   ,.mem_data_cmd_yumi_i(op_mem_data_cmd_yumi_i)

   ,.mem_resp_i(op_mem_resp_i)
   ,.mem_resp_v_i(op_mem_resp_v_i)
   ,.mem_resp_ready_o(op_mem_resp_ready_o)

   ,.mem_data_resp_i(op_mem_data_resp_i)
   ,.mem_data_resp_v_i(op_mem_data_resp_v_i)
   ,.mem_data_resp_ready_o(op_mem_data_resp_ready_o)

   ,.my_cord_i(openpiton_cord_i)

   ,.link_i(op_client_link_li)
   ,.link_o(op_client_link_lo)
   );

assign op_client_link_li.v = cmd_link_lo[P].v;
assign op_client_link_li.data = cmd_link_lo[P].data;
assign op_client_link_li.ready_and_rev = resp_link_lo[P].ready_and_rev;

assign op_master_link_li.v = resp_link_lo[P].v;
assign op_master_link_li.data = resp_link_lo[P].data;
assign op_master_link_li.ready_and_rev = cmd_link_lo[P].ready_and_rev;

assign resp_link_li[P].v = op_client_link_lo.v;
assign resp_link_li[P].data = op_client_link_lo.data;
assign resp_link_li[P].ready_and_rev = op_master_link_lo.ready_and_rev;

assign cmd_link_li[P].v = op_master_link_lo.v;
assign cmd_link_li[P].data = op_master_link_lo.data;
assign cmd_link_li[P].ready_and_rev = op_client_link_lo.ready_and_rev;

// TODO: Disconnected, reconnect with hier coh
assign op_mem_data_resp_ready_lo = '0;
assign op_mem_resp_ready_lo = '0;
assign op_mem_cmd_v_lo = '0;
assign op_mem_data_cmd_v_lo = '0;

endmodule

