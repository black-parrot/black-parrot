/**
 * bp_me_cce_to_wormhole_link_client.v
 */

`include "bp_mem_wormhole.vh"

module bp_me_cce_to_wormhole_link_client

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
  ,localparam num_outstanding_req_p = 16
  )
  
  (input clk_i
  ,input reset_i

  // MEM -> CCE Interface
  ,output logic [cce_mem_cmd_width_lp-1:0]       mem_cmd_o
  ,output logic                                  mem_cmd_v_o
  ,input  logic                                  mem_cmd_yumi_i
                                                 
  // CCE -> MEM Interface                        
  ,input  logic [mem_cce_resp_width_lp-1:0]      mem_resp_i
  ,input  logic                                  mem_resp_v_i
  ,output logic                                  mem_resp_ready_o

  // Configuration
  ,input [mem_noc_cord_width_p-1:0] my_cord_i
    
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

  bp_cmd_wormhole_payload_s  recv_payload_lo;
  bp_resp_wormhole_payload_s send_payload_li;
  bp_cmd_wormhole_packet_s   recv_packet_lo;
  bp_resp_wormhole_packet_s  send_packet_li;

  logic send_ready_li, send_v_lo;
  logic recv_v_li, recv_yumi_lo;

  // We save coordinates between sending and receiving. This assumes we get responses in-order
  logic [mem_noc_cord_width_p-1:0] fifo_cord_li, fifo_cord_lo;
  logic fifo_ready_lo, fifo_v_li, fifo_v_lo, fifo_yumi_li;

  bsg_fifo_1r1w_small 
  #(.width_p(mem_noc_cord_width_p)
    ,.els_p(num_outstanding_req_p)
    )
  cord_fifo
   (.clk_i  (clk_i)
    ,.reset_i(reset_i)

    ,.data_i (fifo_cord_li)
    ,.ready_o(fifo_ready_lo)
    ,.v_i    (fifo_v_li)

    ,.data_o (fifo_cord_lo)
    ,.v_o    (fifo_v_lo)
    ,.yumi_i (fifo_yumi_li)
    );

  bp_me_wormhole_packet_encode_mem_resp
   #(.cfg_p(cfg_p))
   resp_encode
   (.mem_resp_i(mem_resp_i)
    ,.src_cord_i(my_cord_i)
    ,.dst_cord_i(fifo_cord_lo)
    ,.packet_o(send_packet_li)
    );

  assign fifo_cord_li = recv_payload_lo.src_cord;
  assign fifo_v_li    = recv_yumi_lo;
  assign fifo_yumi_li = fifo_v_lo & send_ready_li & send_v_lo;

  assign send_v_lo        = fifo_v_lo & mem_resp_v_i;
  assign mem_resp_ready_o = fifo_v_lo & send_ready_li;
  bsg_wormhole_router_adapter
   #(.max_payload_width_p($bits(bp_resp_wormhole_payload_s))
     ,.len_width_p(mem_noc_len_width_p)
     ,.cord_width_p(mem_noc_cord_width_p)
     ,.link_width_p(mem_noc_width_p)
     )
    adapter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.packet_i(send_packet_li)
     ,.v_i(send_v_lo)
     ,.ready_o(send_ready_li)

     ,.link_i(link_i_cast)
     ,.link_o(link_o_cast)

     ,.packet_o(recv_packet_lo)
     ,.v_o(recv_v_li)
     ,.yumi_i(recv_yumi_lo)
     );
  assign recv_payload_lo = recv_packet_lo.payload;
  assign mem_cmd_o = recv_payload_lo.data;
  assign mem_cmd_v_o = fifo_ready_lo & recv_v_li;
  assign recv_yumi_lo = mem_cmd_yumi_i;

endmodule

