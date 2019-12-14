/**
 * bp_me_cce_to_io_link_client.v
 */

`include "bp_mem_wormhole.vh"

module bp_me_cce_to_io_link_client
  import bp_cce_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_io_if_widths(paddr_width_p, dword_width_p, lce_id_width_p)
  
  , localparam num_outstanding_req_p           = io_noc_max_credits_p
  // wormhole parameters
  , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(io_noc_flit_width_p)
  )
  
  (input                                         clk_i
  , input                                        reset_i

  , output [cce_io_msg_width_lp-1:0]             io_cmd_o
  , output                                       io_cmd_v_o
  , input                                        io_cmd_yumi_i
                                           
  , input [cce_io_msg_width_lp-1:0]              io_resp_i
  , input                                        io_resp_v_i
  , output                                       io_resp_ready_o

  // bsg_noc_wormhole interface
  , input [bsg_ready_and_link_sif_width_lp-1:0]  cmd_link_i
  , output [bsg_ready_and_link_sif_width_lp-1:0] cmd_link_o

  , input [bsg_ready_and_link_sif_width_lp-1:0]  resp_link_i
  , output [bsg_ready_and_link_sif_width_lp-1:0] resp_link_o
  );
  
  `declare_bp_io_if(paddr_width_p, dword_width_p, lce_id_width_p);
  `declare_bp_mem_wormhole_payload_s(io_noc_cord_width_p, cce_io_msg_width_lp, io_cmd_payload_s);
  `declare_bp_mem_wormhole_payload_s(io_noc_cord_width_p, cce_io_msg_width_lp, io_resp_payload_s);
  `declare_bsg_wormhole_router_packet_s(io_noc_cord_width_p, io_noc_len_width_p, $bits(io_cmd_payload_s), io_cmd_packet_s);
  `declare_bsg_wormhole_router_packet_s(io_noc_cord_width_p, io_noc_len_width_p, $bits(io_resp_payload_s), io_resp_packet_s);

  // We save coordinates between sending and receiving. This assumes we get responses in-order
  logic [io_noc_cord_width_p-1:0] fifo_cord_li, fifo_cord_lo;
  logic fifo_ready_lo, fifo_v_li, fifo_v_lo, fifo_yumi_li;

  io_cmd_packet_s io_cmd_packet_lo;
  logic io_cmd_packet_v_lo, io_cmd_packet_yumi_li;
  bsg_wormhole_router_adapter_out
   #(.max_payload_width_p($bits(io_cmd_payload_s))
     ,.len_width_p(io_noc_len_width_p)
     ,.cord_width_p(io_noc_cord_width_p)
     ,.flit_width_p(io_noc_flit_width_p)
     )
   io_cmd_adapter_out
    (.clk_i(clk_i)
      ,.reset_i(reset_i)
  
      ,.link_i(cmd_link_i)
      ,.link_o(cmd_link_o)
  
      ,.packet_o(io_cmd_packet_lo)
      ,.v_o(io_cmd_packet_v_lo)
      ,.yumi_i(io_cmd_packet_yumi_li)
      );
  io_cmd_payload_s io_cmd_payload_lo;
  assign io_cmd_payload_lo = io_cmd_packet_lo.payload;
  assign io_cmd_o = io_cmd_payload_lo.data;
  assign io_cmd_v_o = io_cmd_packet_v_lo & fifo_ready_lo;
  assign io_cmd_packet_yumi_li = io_cmd_yumi_i;
  

  wire bypass_fifo = io_resp_v_i & ~fifo_v_lo;
  assign fifo_cord_li = io_cmd_payload_lo.src_cord;
  assign fifo_v_li    = io_cmd_yumi_i & ~bypass_fifo;
  bsg_fifo_1r1w_small 
  #(.width_p(io_noc_cord_width_p)
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
  assign fifo_yumi_li = fifo_v_lo & io_resp_v_i;

  wire [io_noc_cord_width_p-1:0] src_cord_lo = bypass_fifo ? io_cmd_payload_lo.src_cord : fifo_cord_lo;
  
  wire [io_noc_cord_width_p-1:0] dst_cord_lo = src_cord_lo;

  io_resp_packet_s io_resp_packet_lo;
  bp_me_wormhole_packet_encode_io_resp
   #(.bp_params_p(bp_params_p))
   io_resp_encode
    (.io_resp_i(io_resp_i)
     ,.src_cord_i(src_cord_lo)
     ,.dst_cord_i(dst_cord_lo)
     ,.packet_o(io_resp_packet_lo)
     );
  
  bsg_wormhole_router_adapter_in
   #(.max_payload_width_p($bits(io_resp_payload_s))
     ,.len_width_p(io_noc_len_width_p)
     ,.cord_width_p(io_noc_cord_width_p)
     ,.flit_width_p(io_noc_flit_width_p)
     )
   io_resp_adapter_in
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.packet_i(io_resp_packet_lo)
     ,.v_i(io_resp_v_i)
     ,.ready_o(io_resp_ready_o)
  
     ,.link_i(resp_link_i)
     ,.link_o(resp_link_o)
     );

endmodule

