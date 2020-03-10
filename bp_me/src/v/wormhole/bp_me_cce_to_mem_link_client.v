/**
 * bp_me_cce_to_wormhole_link_client.v
 */

`include "bp_mem_wormhole.vh"

module bp_me_cce_to_mem_link_client
  import bp_cce_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  
   , parameter num_outstanding_req_p = "inv"

   , parameter flit_width_p = "inv"
   , parameter cord_width_p = "inv"
   , parameter cid_width_p  = "inv"
   , parameter len_width_p  = "inv"

  // wormhole parameters
  , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(flit_width_p)
  )
  
  (input                                         clk_i
  , input                                        reset_i

  , output [cce_mem_msg_width_lp-1:0]            mem_cmd_o
  , output                                       mem_cmd_v_o
  , input                                        mem_cmd_yumi_i
                                           
  , input [cce_mem_msg_width_lp-1:0]             mem_resp_i
  , input                                        mem_resp_v_i
  , output                                       mem_resp_ready_o

  // bsg_noc_wormhole interface
  , input [bsg_ready_and_link_sif_width_lp-1:0]  cmd_link_i
  , output [bsg_ready_and_link_sif_width_lp-1:0] resp_link_o
  );
  
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_mem_wormhole_packet_s(flit_width_p, cord_width_p, len_width_p, cid_width_p, cce_mem_msg_width_lp-cce_block_width_p, cce_block_width_p, mem_cmd_packet_s);
  `declare_bp_mem_wormhole_packet_s(flit_width_p, cord_width_p, len_width_p, cid_width_p, cce_mem_msg_width_lp-cce_block_width_p, cce_block_width_p, mem_resp_packet_s);

  localparam payload_width_lp = `bp_mem_wormhole_payload_width(flit_width_p, cord_width_p, len_width_p, cid_width_p, cce_mem_msg_width_lp-cce_block_width_p, cce_block_width_p);

  // We save coordinates between sending and receiving. This assumes we get responses in-order
  logic [cord_width_p-1:0] fifo_cord_li, fifo_cord_lo;
  logic [cid_width_p-1:0] fifo_cid_li, fifo_cid_lo;
  logic fifo_ready_lo, fifo_v_li, fifo_v_lo, fifo_yumi_li;

  mem_cmd_packet_s mem_cmd_packet_lo;
  logic mem_cmd_packet_v_lo, mem_cmd_packet_yumi_li;
  mem_resp_packet_s mem_resp_packet_lo;
  bsg_wormhole_router_adapter
   #(.max_payload_width_p(payload_width_lp)
     ,.len_width_p(len_width_p)
     ,.cord_width_p(cord_width_p)
     ,.flit_width_p(flit_width_p)
     )
   mem_cmd_adapter
    (.clk_i(clk_i)
      ,.reset_i(reset_i)
  
      ,.packet_o(mem_cmd_packet_lo)
      ,.v_o(mem_cmd_packet_v_lo)
      ,.yumi_i(mem_cmd_packet_yumi_li)

      ,.link_i(cmd_link_i)
      ,.link_o(resp_link_o)

      ,.packet_i(mem_resp_packet_lo)
      ,.v_i(mem_resp_v_i)
      ,.ready_o(mem_resp_ready_o)
      );
  assign mem_cmd_o = {mem_cmd_packet_lo.data, mem_cmd_packet_lo.msg};
  assign mem_cmd_v_o = mem_cmd_packet_v_lo & fifo_ready_lo;
  assign mem_cmd_packet_yumi_li = mem_cmd_yumi_i;
  
  wire bypass_fifo = mem_resp_v_i & ~fifo_v_lo;
  assign fifo_cord_li = mem_cmd_packet_lo.src_cord;
  assign fifo_cid_li  = mem_cmd_packet_lo.src_cid;
  assign fifo_v_li    = mem_cmd_yumi_i & ~bypass_fifo;
  bsg_fifo_1r1w_small 
  #(.width_p(cord_width_p+cid_width_p)
    ,.els_p(num_outstanding_req_p)
    )
  cord_fifo
   (.clk_i  (clk_i)
    ,.reset_i(reset_i)

    ,.data_i ({fifo_cord_li, fifo_cid_li})
    ,.ready_o(fifo_ready_lo)
    ,.v_i    (fifo_v_li)

    ,.data_o ({fifo_cord_lo, fifo_cid_lo})
    ,.v_o    (fifo_v_lo)
    ,.yumi_i (fifo_yumi_li)
    );
  assign fifo_yumi_li = fifo_v_lo & mem_resp_v_i;

  wire [cord_width_p-1:0] src_cord_lo = bypass_fifo ? mem_cmd_packet_lo.src_cord : fifo_cord_lo;
  wire [cid_width_p-1:0]  src_cid_lo  = bypass_fifo ? mem_cmd_packet_lo.src_cid  : fifo_cid_lo;
  
  wire [cord_width_p-1:0] dst_cord_lo = src_cord_lo;
  wire [cid_width_p-1:0]  dst_cid_lo  = src_cid_lo;

  bp_me_wormhole_packet_encode_mem_resp
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(flit_width_p)
     ,.cord_width_p(cord_width_p)
     ,.cid_width_p(cid_width_p)
     ,.len_width_p(len_width_p)
     )
   mem_resp_encode
    (.mem_resp_i(mem_resp_i)
     ,.src_cord_i(src_cord_lo)
     ,.src_cid_i(src_cid_lo)
     ,.dst_cord_i(dst_cord_lo)
     ,.dst_cid_i(dst_cid_lo)
     ,.packet_o(mem_resp_packet_lo)
     );
  
endmodule

