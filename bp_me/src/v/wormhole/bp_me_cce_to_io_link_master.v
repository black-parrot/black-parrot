/**
 * bp_me_cce_to_wormhole_link_master.v
 */
 
`include "bp_mem_wormhole.vh"

module bp_me_cce_to_io_link_master
 import bp_cce_pkg::*;
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_io_if_widths(paddr_width_p, dword_width_p, lce_id_width_p)

   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(io_noc_flit_width_p)
   )
  (input                                          clk_i
   , input                                        reset_i

   // CCE-MEM Interface
   , input  [cce_io_msg_width_lp-1:0]             io_cmd_i
   , input                                        io_cmd_v_i
   , output                                       io_cmd_ready_o

   , output [cce_io_msg_width_lp-1:0]             io_resp_o
   , output                                       io_resp_v_o
   , input                                        io_resp_yumi_i
                                                  
   // Configuration
   , input [io_noc_cord_width_p-1:0]              my_cord_i
   , input [io_noc_cord_width_p-1:0]              dst_cord_i
   
   // bsg_noc_wormhole interface
   , input [bsg_ready_and_link_sif_width_lp-1:0]  cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]  resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] resp_link_o
   );
  
// CCE-IO interface packets
`declare_bp_io_if(paddr_width_p, dword_width_p, lce_id_width_p);
  
bp_cce_io_msg_s io_cmd_cast_i, io_resp_cast_o;

assign io_cmd_cast_i = io_cmd_i;
assign io_resp_o = io_resp_cast_o;

// CCE-MEM IF to Wormhole routed interface
`declare_bp_io_wormhole_payload_s(io_noc_cord_width_p, cce_io_msg_width_lp, io_cmd_payload_s);
`declare_bp_io_wormhole_payload_s(io_noc_cord_width_p, cce_io_msg_width_lp, io_resp_payload_s);
`declare_bsg_wormhole_router_packet_s(io_noc_cord_width_p, io_noc_len_width_p, $bits(io_cmd_payload_s), io_cmd_packet_s);
`declare_bsg_wormhole_router_packet_s(io_noc_cord_width_p, io_noc_len_width_p, $bits(io_resp_payload_s), io_resp_packet_s);

io_cmd_packet_s io_cmd_packet_li;
bp_me_wormhole_packet_encode_io_cmd
 #(.bp_params_p(bp_params_p))
 io_cmd_encode
  (.io_cmd_i(io_cmd_cast_i)
   ,.src_cord_i(my_cord_i)
   ,.dst_cord_i(dst_cord_i)
   ,.packet_o(io_cmd_packet_li)
   );

bsg_wormhole_router_adapter_in
 #(.max_payload_width_p($bits(io_cmd_payload_s))
   ,.len_width_p(io_noc_len_width_p)
   ,.cord_width_p(io_noc_cord_width_p)
   ,.flit_width_p(io_noc_flit_width_p)
   )
 io_cmd_adapter_in
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.packet_i(io_cmd_packet_li)
   ,.v_i(io_cmd_v_i)
   ,.ready_o(io_cmd_ready_o)

   ,.link_i(cmd_link_i)
   ,.link_o(cmd_link_o)
   );

io_resp_packet_s io_resp_packet_lo;
bsg_wormhole_router_adapter_out
 #(.max_payload_width_p($bits(io_resp_payload_s))
   ,.len_width_p(io_noc_len_width_p)
   ,.cord_width_p(io_noc_cord_width_p)
   ,.flit_width_p(io_noc_flit_width_p)
   )
 io_resp_adapter_out
  (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_i(resp_link_i)
    ,.link_o(resp_link_o)

    ,.packet_o(io_resp_packet_lo)
    ,.v_o(io_resp_v_o)
    ,.yumi_i(io_resp_yumi_i)
    );
io_resp_payload_s io_resp_payload_lo;
assign io_resp_payload_lo = io_resp_packet_lo.payload;
assign io_resp_cast_o = io_resp_payload_lo.data;

endmodule

