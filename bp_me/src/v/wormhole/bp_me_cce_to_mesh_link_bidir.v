
`include "bp_io_mesh.vh"

module bp_me_cce_to_wormhole_link_bidir
 import bp_cce_pkg::*;
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

  , localparam io_cmd_payload_width_lp  = `bp_io_mesh_payload_width(io_noc_cord_width_p, cce_mem_msg_width_lp)
  , localparam io_resp_payload_width_lp = `bp_io_mesh_payload_width(io_noc_cord_width_p, cce_mem_msg_width_lp)
  , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(io_noc_flit_width_p)
  )

  (input                                          clk_i
   , input                                        reset_i

   // Configuration
   , input [io_noc_cord_width_p-1:0]              my_cord_i
   , input [io_noc_cord_width_p-1:0]              dst_cord_i

   // Master link
   , input  [cce_mem_msg_width_lp-1:0]            io_cmd_i
   , input                                        io_cmd_v_i
   , output                                       io_cmd_ready_o

   , output [cce_mem_msg_width_lp-1:0]            io_resp_o
   , output                                       io_resp_v_o
   , input                                        io_resp_yumi_i

   // Client link
   , output  [cce_mem_msg_width_lp-1:0]           io_cmd_o
   , output                                       io_cmd_v_o
   , input                                        io_cmd_yumi_i

   , input [cce_mem_msg_width_lp-1:0]             io_resp_i
   , input                                        io_resp_v_i
   , output                                       io_resp_ready_o

   // NOC interface
   , input [bsg_ready_and_link_sif_width_lp-1:0]  cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]  resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] resp_link_o
   );

`declare_bsg_mesh_packet_s(io_noc_cord_width_p, io_cmd_payload_width_lp, bp_io_cmd_packet_s);
`declare_bsg_ready_and_link_sif_s($bits(bp_io_cmd_packet_s), bsg_ready_and_link_sif_s);
bsg_ready_and_link_sif_s cmd_link_cast_i, cmd_link_cast_o;
bsg_ready_and_link_sif_s resp_link_cast_i, resp_link_cast_o;

bsg_ready_and_link_sif_s master_cmd_link_li, master_cmd_link_lo;
bsg_ready_and_link_sif_s master_resp_link_li, master_resp_link_lo;
bsg_ready_and_link_sif_s client_cmd_link_li, client_cmd_link_lo;
bsg_ready_and_link_sif_s client_resp_link_li, client_resp_link_lo;

assign cmd_link_cast_i  = cmd_link_i;
assign resp_link_cast_i = resp_link_i;

assign cmd_link_o  = cmd_link_cast_o;
assign resp_link_o = resp_link_cast_o;

assign master_cmd_link_li  = '{ready_and_rev: cmd_link_cast_i.ready_and_rev, default: '0};
assign client_cmd_link_li  = cmd_link_cast_i;
assign cmd_link_cast_o     = '{data          : master_cmd_link_lo.data
                               ,v            : master_cmd_link_lo.v
                               ,ready_and_rev: client_cmd_link_lo.ready_and_rev
                               };

assign master_resp_link_li = resp_link_cast_i;
assign client_resp_link_li = '{ready_and_rev: resp_link_cast_i.ready_and_rev, default: '0};
assign resp_link_cast_o    = '{data          : client_resp_link_lo.data
                               ,v            : client_resp_link_lo.v
                               ,ready_and_rev: master_resp_link_lo.ready_and_rev
                               };

bp_me_cce_to_mesh_link_master
 #(.bp_params_p(bp_params_p))
  master_link
  (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.io_cmd_i(io_cmd_i)
  ,.io_cmd_v_i(io_cmd_v_i)
  ,.io_cmd_ready_o(io_cmd_ready_o)

  ,.io_resp_o(io_resp_o)
  ,.io_resp_v_o(io_resp_v_o)
  ,.io_resp_yumi_i(io_resp_yumi_i)

  ,.my_did_i(my_did_i)
  ,.my_cord_i(my_cord_i)
  ,.dst_did_i(dst_did_i)
  ,.dst_cord_i(dst_cord_i)
  
  ,.cmd_link_i(master_cmd_link_li)
  ,.cmd_link_o(master_cmd_link_lo)

  ,.resp_link_i(master_resp_link_li)
  ,.resp_link_o(master_resp_link_lo)
  );

bp_me_cce_to_mesh_link_client
 #(.bp_params_p(bp_params_p))
  client_link
  (.clk_i(clk_i)
  ,.reset_i(reset_i)

  ,.io_cmd_o(io_cmd_o)
  ,.io_cmd_v_o(io_cmd_v_o)
  ,.io_cmd_yumi_i(io_cmd_yumi_i)

  ,.io_resp_i(io_resp_i)
  ,.io_resp_v_i(io_resp_v_i)
  ,.io_resp_ready_o(io_resp_ready_o)

  ,.cmd_link_i(client_cmd_link_li)
  ,.cmd_link_o(client_cmd_link_lo)

  ,.resp_link_i(client_resp_link_li)
  ,.resp_link_o(client_resp_link_lo)
  );

endmodule

