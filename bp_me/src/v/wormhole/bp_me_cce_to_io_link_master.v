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
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   , localparam io_cmd_payload_width_lp  = `bp_io_mesh_payload_width(io_noc_cord_width_p, cce_mem_msg_width_lp)
   , localparam io_resp_payload_width_lp = `bp_io_mesh_payload_width(io_noc_cord_width_p, cce_mem_msg_width_lp)
   , localparam bsg_ready_and_link_sif_width_lp = `bsg_ready_and_link_sif_width(io_noc_flit_width_p)
   )
  (input                                          clk_i
   , input                                        reset_i

   // CCE-MEM Interface
   , input  [cce_mem_msg_width_lp-1:0]            io_cmd_i
   , input                                        io_cmd_v_i
   , output                                       io_cmd_ready_o

   , output [cce_mem_msg_width_lp-1:0]            io_resp_o
   , output                                       io_resp_v_o
   , input                                        io_resp_yumi_i
                                                  
   // Configuration
   , input [io_noc_cord_width_p-1:0]              my_cord_i
   , input [io_noc_cord_width_p-1:0]              dst_cord_i
   
   // bsg_noc_wormhole interface
   , input [bsg_ready_and_link_sif_width_lp-1:0]  io_cmd_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] io_cmd_link_o

   , input [bsg_ready_and_link_sif_width_lp-1:0]  io_resp_link_i
   , output [bsg_ready_and_link_sif_width_lp-1:0] io_resp_link_o
   );
  
  // CCE-MEM interface packets
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
    
  bp_cce_mem_msg_s io_cmd_cast_i, io_resp_cast_o;
  
  assign io_cmd_cast_i = io_cmd_i;
  assign io_resp_o = io_resp_cast_o;
  
  // CCE-MEM IF to Wormhole routed interface
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
  
  bp_io_cmd_packet_s io_cmd_packet_li;
  bp_me_mesh_packet_encode_io_cmd
   #(.bp_params_p(bp_params_p))
   io_cmd_encode
    (.io_cmd_i(io_cmd_i)
     ,.src_cord_i(my_cord_i)
     ,.dst_cord_i(dst_cord_i)
     ,.packet_o(io_cmd_packet_li)
     );
  
  always_comb
    begin
      io_cmd_link_cast_o.v             = io_cmd_v_i;
      io_cmd_link_cast_o.ready_and_rev = '0;
      io_cmd_link_cast_o.data          = io_cmd_packet_li;

      io_cmd_ready_o = io_cmd_link_cast_i.ready_and_rev;
    end 

  bsg_two_fifo
   #(.width_p($bits(bp_io_cmd_packet_s)))
   resp_buffer
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(io_resp_link_cast_i.data)
     ,.v_i(io_resp_link_cast_i.v)
     ,.ready_o(io_resp_link_cast_o.ready_o)

     ,.data_o(io_resp_cast_o)
     ,.v_o(io_resp_v_o)
     ,.yumi_i(io_resp_yumi_i)
     );
  assign io_resp_link_cast_o.v    = '0;
  assign io_resp_link_cast_o.data = '0;

endmodule

