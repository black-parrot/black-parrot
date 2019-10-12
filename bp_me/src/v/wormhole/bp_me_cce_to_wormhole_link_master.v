/**
 * bp_me_cce_to_wormhole_link_master.v
 */
 
`include "bp_mem_wormhole.vh"

module bp_me_cce_to_wormhole_link_master
 import bp_cce_pkg::*;
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                          clk_i
   , input                                        reset_i

   // CCE-MEM Interface
   , input  [cce_mem_msg_width_lp-1:0]            mem_cmd_i
   , input                                        mem_cmd_v_i
   , output                                       mem_cmd_ready_o
                                                   
   , output [cce_mem_msg_width_lp-1:0]            mem_resp_o
   , output                                       mem_resp_v_o
   , input                                        mem_resp_yumi_i
                                                  
   // Configuration
   , input [mem_noc_cord_width_p-1:0]             my_cord_i
   , input [mem_noc_cid_width_p-1:0]              my_cid_i
   , input [mem_noc_cord_width_p-1:0]             dst_cord_i
   , input [mem_noc_cid_width_p-1:0]              dst_cid_i
   
   // bsg_noc_wormhole interface
   , input [bsg_ready_and_link_sif_width_lp-1:0]  cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]  resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] resp_link_o
   );
  
// CCE-MEM interface packets
`declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
  
bp_cce_mem_msg_s mem_cmd_cast_i, mem_resp_cast_o;

assign mem_cmd_cast_i = mem_cmd_i;
assign mem_resp_o = mem_resp_cast_o;

// CCE-MEM IF to Wormhole routed interface
`declare_bp_mem_wormhole_payload_s(mem_noc_reserved_width_p, mem_noc_cord_width_p, mem_noc_cid_width_p, cce_mem_msg_width_lp, mem_cmd_payload_s);
`declare_bp_mem_wormhole_payload_s(mem_noc_reserved_width_p, mem_noc_cord_width_p, mem_noc_cid_width_p, cce_mem_msg_width_lp, mem_resp_payload_s);
`declare_bsg_wormhole_concentrator_packet_s(mem_noc_cord_width_p, mem_noc_len_width_p, mem_noc_cid_width_p, $bits(mem_cmd_payload_s), mem_cmd_packet_s);
`declare_bsg_wormhole_concentrator_packet_s(mem_noc_cord_width_p, mem_noc_len_width_p, mem_noc_cid_width_p, $bits(mem_resp_payload_s), mem_resp_packet_s);

mem_cmd_packet_s mem_cmd_packet_li;
bp_me_wormhole_packet_encode_mem_cmd
 #(.bp_params_p(bp_params_p))
 mem_cmd_encode
  (.mem_cmd_i(mem_cmd_cast_i)
   ,.src_cord_i(my_cord_i)
   ,.src_cid_i(my_cid_i)
   ,.dst_cord_i(dst_cord_i)
   ,.dst_cid_i(dst_cid_i)
   ,.packet_o(mem_cmd_packet_li)
   );

bsg_wormhole_router_adapter_in
 #(.max_payload_width_p($bits(mem_cmd_payload_s)+mem_noc_cid_width_p)
   ,.len_width_p(mem_noc_len_width_p)
   ,.cord_width_p(mem_noc_cord_width_p)
   ,.flit_width_p(mem_noc_flit_width_p)
   )
 mem_cmd_adapter_in
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.packet_i(mem_cmd_packet_li)
   ,.v_i(mem_cmd_v_i)
   ,.ready_o(mem_cmd_ready_o)

   ,.link_i(cmd_link_i)
   ,.link_o(cmd_link_o)
   );

mem_resp_packet_s mem_resp_packet_lo;
bsg_wormhole_router_adapter_out
 #(.max_payload_width_p($bits(mem_resp_payload_s)+mem_noc_cid_width_p)
   ,.len_width_p(mem_noc_len_width_p)
   ,.cord_width_p(mem_noc_cord_width_p)
   ,.flit_width_p(mem_noc_flit_width_p)
   )
 mem_resp_adapter_out
  (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.link_i(resp_link_i)
    ,.link_o(resp_link_o)

    ,.packet_o(mem_resp_packet_lo)
    ,.v_o(mem_resp_v_o)
    ,.yumi_i(mem_resp_yumi_i)
    );
mem_resp_payload_s mem_resp_payload_lo;
assign mem_resp_payload_lo = mem_resp_packet_lo.payload;
assign mem_resp_cast_o = mem_resp_payload_lo.data;

endmodule

