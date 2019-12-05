
module bp_io_tile
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                    clk_i
   , input                                  reset_i

   , input [mem_noc_did_width_p-1:0]        my_did_i
   , input [mem_noc_cord_width_p-1:0]       my_cord_i

   , input [coh_noc_ral_link_width_lp-1:0]  lce_req_link_i
   , output [coh_noc_ral_link_width_lp-1:0] lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]  lce_cmd_link_i
   , output [coh_noc_ral_link_width_lp-1:0] lce_cmd_link_o

   , input [mem_noc_ral_link_width_lp-1:0]  io_cmd_link_i
   , output [mem_noc_ral_link_width_lp-1:0] io_cmd_link_o

   , input [mem_noc_ral_link_width_lp-1:0]  io_resp_link_i
   , output [mem_noc_ral_link_width_lp-1:0] io_resp_link_o
   );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p);

  `declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cce_req_width_lp, lce_req_packet_s);
  `declare_bsg_wormhole_concentrator_packet_s(coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, lce_cmd_width_lp, lce_cmd_packet_s);

  bp_lce_cce_req_s  cce_lce_req_li, lce_lce_req_lo;
  logic cce_lce_req_v_li, cce_lce_req_yumi_lo, lce_lce_req_v_lo, lce_lce_req_ready_li;
  bp_lce_cmd_s cce_lce_cmd_lo, lce_lce_cmd_li;
  logic cce_lce_cmd_v_lo, cce_lce_cmd_ready_li, lce_lce_cmd_v_li, lce_lce_cmd_yumi_lo;

  bp_cce_mem_msg_s cce_io_cmd_lo, lce_io_cmd_li;
  logic cce_io_cmd_v_lo, cce_io_cmd_ready_li, lce_io_cmd_v_li, lce_io_cmd_yumi_lo;
  bp_cce_mem_msg_s cce_io_resp_li, lce_io_resp_lo;
  logic cce_io_resp_v_li, cce_io_resp_yumi_lo, lce_io_resp_v_lo, lce_io_resp_ready_li;

  logic [cce_id_width_p-1:0]  cce_id_li;
  logic [lce_id_width_p-1:0]  lce_id_li;
  bp_me_cord_to_id
   #(.bp_params_p(bp_params_p))
   id_map
    (.cord_i(my_cord_i)
     ,.core_id_o()
     ,.cce_id_o(cce_id_li)
     ,.lce_id0_o(lce_id_li)
     ,.lce_id1_o()
     );

  bp_io_link_to_lce
   #(.bp_params_p(bp_params_p))
   lce_link
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i(lce_id_li)

     ,.io_cmd_i(lce_io_cmd_li)
     ,.io_cmd_v_i(lce_io_cmd_v_li)
     ,.io_cmd_yumi_o(lce_io_cmd_yumi_lo)

     ,.io_resp_o(lce_io_resp_lo)
     ,.io_resp_v_o(lce_io_resp_v_lo)
     ,.io_resp_ready_i(lce_io_resp_ready_li)

     ,.lce_req_o(lce_lce_req_lo)
     ,.lce_req_v_o(lce_lce_req_v_lo)
     ,.lce_req_ready_i(lce_lce_req_ready_li)

     ,.lce_cmd_i(lce_lce_cmd_li)
     ,.lce_cmd_v_i(lce_lce_cmd_v_li)
     ,.lce_cmd_yumi_o(lce_lce_cmd_yumi_lo)
     );

  bp_io_cce
   #(.bp_params_p(bp_params_p))
   io_cce
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.cce_id_i(cce_id_li)

     ,.lce_req_i(cce_lce_req_li)
     ,.lce_req_v_i(cce_lce_req_v_li)
     ,.lce_req_yumi_o(cce_lce_req_yumi_lo)

     ,.lce_cmd_o(cce_lce_cmd_lo)
     ,.lce_cmd_v_o(cce_lce_cmd_v_lo)
     ,.lce_cmd_ready_i(cce_lce_cmd_ready_li)

     ,.io_cmd_o(cce_io_cmd_lo)
     ,.io_cmd_v_o(cce_io_cmd_v_lo)
     ,.io_cmd_ready_i(cce_io_cmd_ready_li)

     ,.io_resp_i(cce_io_resp_li)
     ,.io_resp_v_i(cce_io_resp_v_li)
     ,.io_resp_yumi_o(cce_io_resp_yumi_lo)
     );

  lce_req_packet_s lce_req_packet_li, lce_req_packet_lo;
  bp_me_wormhole_packet_encode_lce_req
   #(.bp_params_p(bp_params_p))
   req_encode
    (.payload_i(lce_lce_req_lo)
     ,.packet_o(lce_req_packet_lo)
     );

  bsg_wormhole_router_adapter
   #(.max_payload_width_p($bits(lce_req_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   lce_req_adapter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.packet_i(lce_req_packet_lo)
     ,.v_i(lce_lce_req_v_lo)
     ,.ready_o(lce_lce_req_ready_li)

     ,.link_i(lce_req_link_i)
     ,.link_o(lce_req_link_o)

     ,.packet_o(lce_req_packet_li)
     ,.v_o(cce_lce_req_v_li)
     ,.yumi_i(cce_lce_req_yumi_lo)
     );
  assign cce_lce_req_li = lce_req_packet_li.payload;

  lce_cmd_packet_s lce_cmd_packet_li, lce_cmd_packet_lo;
  bp_me_wormhole_packet_encode_lce_cmd
   #(.bp_params_p(bp_params_p))
   cmd_encode
    (.payload_i(cce_lce_cmd_lo)
     ,.packet_o(lce_cmd_packet_lo)
     );

  bsg_wormhole_router_adapter
   #(.max_payload_width_p($bits(lce_cmd_packet_s)-coh_noc_cord_width_p-coh_noc_len_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   lce_cmd_adapter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.packet_i(lce_cmd_packet_lo)
     ,.v_i(cce_lce_cmd_v_lo)
     ,.ready_o(cce_lce_cmd_ready_li)

     ,.link_i(lce_cmd_link_i)
     ,.link_o(lce_cmd_link_o)

     ,.packet_o(lce_cmd_packet_li)
     ,.v_o(lce_lce_cmd_v_li)
     ,.yumi_i(lce_lce_cmd_yumi_lo)
     );
  assign lce_lce_cmd_li = lce_cmd_packet_li.payload;

  logic [mem_noc_did_width_p-1:0]  dst_did_lo;
  logic [mem_noc_cord_width_p-1:0] dst_cord_lo;

  wire is_host_addr = ((cce_io_cmd_lo.addr >= host_dev_base_addr_gp) 
                      && (cce_io_cmd_lo.addr < cce_dev_base_addr_gp));
  assign dst_did_lo = is_host_addr ? '1 : cce_io_cmd_lo.addr[paddr_width_p-1-:mem_noc_did_width_p];
  assign dst_cord_lo = dst_did_lo;

  bp_me_cce_to_wormhole_link_bidir
   #(.bp_params_p(bp_params_p))
   io_link
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(cce_io_cmd_lo)
     ,.mem_cmd_v_i(cce_io_cmd_v_lo)
     ,.mem_cmd_ready_o(cce_io_cmd_ready_li)

     ,.mem_resp_o(cce_io_resp_li)
     ,.mem_resp_v_o(cce_io_resp_v_li)
     ,.mem_resp_yumi_i(cce_io_resp_yumi_lo)

     ,.mem_cmd_o(lce_io_cmd_li)
     ,.mem_cmd_v_o(lce_io_cmd_v_li)
     ,.mem_cmd_yumi_i(lce_io_cmd_yumi_lo)

     ,.mem_resp_i(lce_io_resp_lo)
     ,.mem_resp_v_i(lce_io_resp_v_lo)
     ,.mem_resp_ready_o(lce_io_resp_ready_li)

     ,.my_did_i(my_did_i)
     ,.my_cord_i(mem_noc_cord_width_p'(my_did_i))
     ,.my_cid_i('0)
     ,.dst_did_i(dst_did_lo)
     ,.dst_cord_i(dst_cord_lo)
     ,.dst_cid_i('0)

     ,.cmd_link_i(io_cmd_link_i)
     ,.cmd_link_o(io_cmd_link_o)

     ,.resp_link_i(io_resp_link_i)
     ,.resp_link_o(io_resp_link_o)
     );


endmodule

