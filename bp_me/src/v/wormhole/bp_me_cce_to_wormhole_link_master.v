/**
 * bp_me_cce_to_wormhole_link_master.v
 */
 
`include "bp_mem_wormhole.vh"

module bp_me_cce_to_wormhole_link_master

  import bp_cce_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_me_pkg::*;
  
 #(parameter bp_cfg_e cfg_p = e_bp_inv_cfg
  
  `declare_bp_proc_params(cfg_p)
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)
  
  // wormhole parameters
  ,localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(mem_noc_width_p)

  ,localparam word_select_bits_lp  = `BSG_SAFE_CLOG2(cce_block_width_p / dword_width_p)
  ,localparam byte_offset_bits_lp  = `BSG_SAFE_CLOG2(dword_width_p / 8)
  )
  
  (input clk_i
  ,input reset_i

  // CCE-MEM Interface
  // CCE to Mem, Mem is demanding and uses vaild->ready (valid-yumi)
  ,input  logic [cce_mem_cmd_width_lp-1:0]       mem_cmd_i
  ,input  logic                                  mem_cmd_v_i
  ,output logic                                  mem_cmd_yumi_o
                                                 
  // Mem to CCE, Mem is demanding and uses ready->valid
  ,output logic [mem_cce_resp_width_lp-1:0]      mem_resp_o
  ,output logic                                  mem_resp_v_o
  ,input  logic                                  mem_resp_ready_i
                                                 
  // Configuration
  ,input [mem_noc_cord_width_p-1:0] my_cord_i
  
  ,input [mem_noc_cord_width_p-1:0] mem_cmd_dest_cord_i
  
  // bsg_noc_wormhole interface
  ,input  [bsg_ready_and_link_sif_width_lp-1:0] link_i
  ,output [bsg_ready_and_link_sif_width_lp-1:0] link_o
  );
  
  /********************** noc link interface ***********************/
  
  `declare_bsg_ready_and_link_sif_s(mem_noc_width_p,bsg_ready_and_link_sif_s);
  bsg_ready_and_link_sif_s link_i_cast, link_o_cast;
  assign link_i_cast = link_i;
  assign link_o = link_o_cast;
    
  /********************** Packet definition ***********************/
  
  // CCE-MEM interface packets
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);
  
  // Wormhole packet definition
  `declare_bp_mem_wormhole_payload_s(mem_noc_reserved_width_p, mem_noc_cord_width_p, cce_mem_cmd_width_lp, bp_cmd_wormhole_payload_s);
  `declare_bp_mem_wormhole_payload_s(mem_noc_reserved_width_p, mem_noc_cord_width_p, mem_cce_resp_width_lp, bp_resp_wormhole_payload_s);
  `declare_bsg_wormhole_router_packet_s(mem_noc_cord_width_p, mem_noc_len_width_p, $bits(bp_cmd_wormhole_payload_s), bp_cmd_wormhole_packet_s);
  `declare_bsg_wormhole_router_packet_s(mem_noc_cord_width_p, mem_noc_len_width_p, $bits(bp_resp_wormhole_payload_s), bp_resp_wormhole_packet_s);
 
  bp_cmd_wormhole_payload_s  send_payload_lo;
  bp_resp_wormhole_payload_s recv_payload_li;
  bp_cmd_wormhole_packet_s   send_packet_lo;
  bp_resp_wormhole_packet_s  recv_packet_li;

  logic send_ready_li, send_v_lo;
  logic recv_ready_lo, recv_v_li;

  bp_me_wormhole_packet_encode_mem_cmd
   #(.cfg_p(cfg_p))
   cmd_encode
   (.mem_cmd_i(mem_cmd_i)
    ,.src_cord_i(my_cord_i)
    ,.dst_cord_i(mem_cmd_dest_cord_i)
    ,.packet_o(send_packet_lo)
    );

  assign send_v_lo      = mem_cmd_v_i;
  assign mem_cmd_yumi_o = send_v_lo & send_ready_li;
  bsg_wormhole_router_adapter
   #(.max_payload_width_p($bits(bp_cmd_wormhole_payload_s))
     ,.len_width_p(mem_noc_len_width_p)
     ,.cord_width_p(mem_noc_cord_width_p)
     ,.link_width_p(mem_noc_width_p)
     )
    adapter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.packet_i(send_packet_lo)
     ,.v_i(send_v_lo)
     ,.ready_o(send_ready_li)

     ,.link_i(link_i_cast)
     ,.link_o(link_o_cast)

     ,.packet_o(recv_packet_li)
     ,.v_o(recv_v_li)
     ,.yumi_i(recv_ready_lo & recv_v_li)
     );
  assign recv_payload_li = recv_packet_li.payload;
  assign mem_resp_o = recv_payload_li.data;
  assign mem_resp_v_o = recv_v_li;
  assign recv_ready_lo = mem_resp_ready_i;
  
endmodule

