/**
 * bp_me_cce_to_wormhole_link_client.v
 */

`include "bp_io_mesh.vh"

module bp_me_cce_to_mesh_link_client
  import bp_cce_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
  `declare_bp_proc_params(bp_params_p)
  `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  
  // TODO: Should be related to network credits
  , localparam num_outstanding_req_p    = 16
  , localparam io_cmd_payload_width_lp  = `bp_io_mesh_payload_width(io_noc_cord_width_p, cce_mem_msg_width_lp)
  , localparam io_resp_payload_width_lp = `bp_io_mesh_payload_width(io_noc_cord_width_p, cce_mem_msg_width_lp)
  , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(io_cmd_payload_width_lp)
  )
  
  (input                                         clk_i
  , input                                        reset_i

  , output [cce_mem_msg_width_lp-1:0]            io_cmd_o
  , output                                       io_cmd_v_o
  , input                                        io_cmd_yumi_i
                                           
  , input [cce_mem_msg_width_lp-1:0]             io_resp_i
  , input                                        io_resp_v_i
  , output                                       io_resp_ready_o

  // bsg_noc_mesh interface
  , input [bsg_ready_and_link_sif_width_lp-1:0]  io_cmd_link_i
  , output [bsg_ready_and_link_sif_width_lp-1:0] io_cmd_link_o

  , input [bsg_ready_and_link_sif_width_lp-1:0]  io_resp_link_i
  , output [bsg_ready_and_link_sif_width_lp-1:0] io_resp_link_o
  );
  
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);

  bp_cce_mem_msg_s io_cmd_cast_o, io_resp_cast_i;

  `declare_bp_io_mesh_payload_s(io_noc_cord_width_p, $bits(bp_cce_mem_msg_s), bp_io_cmd_payload_s);
  `declare_bsg_mesh_packet_s(io_noc_cord_width_p, io_cmd_payload_width_lp, bp_io_cmd_packet_s);
  `declare_bsg_mesh_packet_s(io_noc_cord_width_p, io_resp_payload_width_lp, bp_io_resp_packet_s);
  `declare_bsg_ready_and_link_sif_s($bits(bp_io_cmd_packet_s), bp_io_cmd_link_s);
  `declare_bsg_ready_and_link_sif_s($bits(bp_io_resp_packet_s), bp_io_resp_link_s);

  bp_io_cmd_link_s io_cmd_link_cast_i, io_cmd_link_cast_o;
  bp_io_resp_link_s io_resp_link_cast_i, io_resp_link_cast_o;

  assign io_cmd_link_cast_i  = io_cmd_link_i;
  assign io_cmd_link_o       = io_cmd_link_cast_o;
  assign io_resp_link_cast_i = io_resp_link_i;
  assign io_resp_link_o      = io_resp_link_cast_o;

  bp_io_cmd_packet_s  io_cmd_packet_lo;
  bp_io_cmd_payload_s io_cmd_payload_lo;
  bp_cce_mem_msg_s    io_cmd_lo;
  logic io_cmd_packet_v_lo, io_cmd_packet_yumi_li;
  assign io_cmd_link_cast_o.v    = '0;
  assign io_cmd_link_cast_o.data = '0;
  bsg_two_fifo
   #(.width_p($bits(bp_io_cmd_packet_s)))
   cmd_buffer
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(io_cmd_link_cast_i.data)
     ,.v_i(io_cmd_link_cast_i.v)
     ,.ready_o(io_cmd_link_cast_o.ready_o)

     ,.data_o(io_cmd_packet_lo)
     ,.v_o(io_cmd_packet_v_lo)
     ,.yumi_i(io_cmd_packet_yumi_li)
     );
  assign io_cmd_payload_lo = io_cmd_packet_lo.payload;
  assign io_cmd_o          = io_cmd_payload_lo.data;

  // We save coordinates between sending and receiving. This assumes we get responses in-order
  logic [mem_noc_cord_width_p-1:0] fifo_cord_li, fifo_cord_lo;
  logic fifo_ready_lo, fifo_v_li, fifo_v_lo, fifo_yumi_li;

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
   (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.data_i(fifo_cord_li)
    ,.ready_o(fifo_ready_lo)
    ,.v_i(fifo_v_li)

    ,.data_o(fifo_cord_lo)
    ,.v_o(fifo_v_lo)
    ,.yumi_i(fifo_yumi_li)
    );
  assign fifo_yumi_li = fifo_v_lo & io_resp_v_i;

  wire [mem_noc_cord_width_p-1:0] src_cord_lo = bypass_fifo ? fifo_cord_li : fifo_cord_lo;
  wire [mem_noc_cord_width_p-1:0] dst_cord_lo = src_cord_lo;

  bp_io_resp_packet_s io_resp_packet_li;
  bp_me_mesh_packet_encode_io_resp
   #(.bp_params_p(bp_params_p))
   io_resp_encode
    (.io_resp_i(io_resp_i)
     ,.src_cord_i(src_cord_lo)
     ,.dst_cord_i(dst_cord_lo)
     ,.packet_o(io_resp_packet_li)
     );

  always_comb
    begin
      io_resp_link_cast_o.v             = io_resp_v_i;
      io_resp_link_cast_o.ready_and_rev = '0;
      io_resp_link_cast_o.data          = io_resp_packet_li;

      io_resp_ready_o = io_resp_link_cast_i.ready_and_rev;
    end

endmodule

