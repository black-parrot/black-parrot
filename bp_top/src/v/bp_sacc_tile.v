module bp_sacc_tile
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bsg_cache_pkg::*;
   import bp_be_pkg::*;
   import bsg_noc_pkg::*;
   import bp_common_cfg_link_pkg::*;
   import bsg_wormhole_router_pkg::*;
  
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, cce_block_width_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam io_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(io_noc_flit_width_p)
   , parameter accelerator_type_p = e_sacc_vdp
   )
  (input                                    clk_i
   , input                                  reset_i

   , input [coh_noc_cord_width_p-1:0]       my_cord_i
   
   , input [coh_noc_ral_link_width_lp-1:0]  lce_req_link_i
   , output [coh_noc_ral_link_width_lp-1:0] lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]  lce_cmd_link_i
   , output [coh_noc_ral_link_width_lp-1:0] lce_cmd_link_o

   );

  `declare_bp_mem_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem);
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, cce_block_width_p);
  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
 
  //io-cce-side connections 
  bp_lce_cce_req_s  cce_lce_req_li, lce_lce_req_lo;
  logic cce_lce_req_v_li, cce_lce_req_yumi_lo, lce_lce_req_v_lo, lce_req_ready_li;
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
     ,.lce_req_ready_i(lce_req_ready_li)

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

  `declare_bp_lce_req_wormhole_packet_s(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, bp_lce_cce_req_header_s, cce_block_width_p);
  localparam lce_req_payload_width_lp = `bp_coh_wormhole_payload_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, $bits(bp_lce_cce_req_header_s), cce_block_width_p);
  bp_lce_req_wormhole_packet_s lce_req_packet_li, lce_req_packet_lo;
  bp_lce_req_wormhole_header_s lce_req_header_li, lce_req_header_lo;

  bp_me_wormhole_packet_encode_lce_req
   #(.bp_params_p(bp_params_p))
   req_encode
    (.lce_req_header_i(lce_lce_req_lo.header)
     ,.wh_header_o(lce_req_header_lo)
     );
   assign lce_req_packet_lo = '{header: lce_req_header_lo, data: lce_lce_req_lo.data};

  bsg_wormhole_router_adapter
   #(.max_payload_width_p(lce_req_payload_width_lp)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   lce_req_adapter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.packet_i(lce_req_packet_lo)
     ,.v_i(lce_lce_req_v_lo)
     ,.ready_o(lce_req_ready_li)

     ,.link_i(lce_req_link_i)
     ,.link_o(lce_req_link_o)

     ,.packet_o(lce_req_packet_li)
     ,.v_o(cce_lce_req_v_li)
     ,.yumi_i(cce_lce_req_yumi_lo)
     );
   assign cce_lce_req_li = '{header: lce_req_packet_li.header.msg_hdr, data: lce_req_packet_li.data};

  `declare_bp_lce_cmd_wormhole_packet_s(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, bp_lce_cmd_header_s, cce_block_width_p);
  localparam lce_cmd_payload_width_lp = `bp_coh_wormhole_payload_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, $bits(bp_lce_cmd_header_s), cce_block_width_p);
  bp_lce_cmd_wormhole_packet_s lce_cmd_packet_li, cce_lce_cmd_packet_lo;
  bp_lce_cmd_wormhole_header_s lce_cmd_header_li, cce_lce_cmd_header_lo;

  bp_me_wormhole_packet_encode_lce_cmd
   #(.bp_params_p(bp_params_p))
   cce_cmd_encode
    (.lce_cmd_header_i(cce_lce_cmd_lo.header)
     ,.wh_header_o(cce_lce_cmd_header_lo)
     );
  assign cce_lce_cmd_packet_lo = '{header: cce_lce_cmd_header_lo, data: cce_lce_cmd_lo.data};
  
  bsg_wormhole_router_adapter
   #(.max_payload_width_p(lce_cmd_payload_width_lp)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     )
   cmd_adapter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.packet_i(cce_lce_cmd_packet_lo)
     ,.v_i(cce_lce_cmd_v_lo)
     ,.ready_o(cce_lce_cmd_ready_li)

     ,.link_i(lce_cmd_link_i)
     ,.link_o(lce_cmd_link_o)

     ,.packet_o(lce_cmd_packet_li)
     ,.v_o(lce_lce_cmd_v_li)
     ,.yumi_i(lce_lce_cmd_yumi_lo)
     );
   assign lce_lce_cmd_li = '{header: lce_cmd_packet_li.header.msg_hdr, data: lce_cmd_packet_li.data};

  if (sacc_type_p == e_sacc_vdp)
    begin : sacc_vdp
      bp_sacc_vdp
       #(.bp_params_p(bp_params_p))
       accelerator_link
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.lce_id_i(lce_id_li)

         ,.io_cmd_i(cce_io_cmd_lo)
         ,.io_cmd_v_i(cce_io_cmd_v_lo)
         ,.io_cmd_ready_o(cce_io_cmd_ready_li)

         ,.io_resp_o(cce_io_resp_li)
         ,.io_resp_v_o(cce_io_resp_v_li)
         ,.io_resp_yumi_i(cce_io_resp_yumi_lo)

         ,.io_cmd_o(lce_io_cmd_li)
         ,.io_cmd_v_o(lce_io_cmd_v_li)
         ,.io_cmd_yumi_i(lce_io_cmd_yumi_lo)

         ,.io_resp_i(lce_io_resp_lo)
         ,.io_resp_v_i(lce_io_resp_v_lo)
         ,.io_resp_ready_o(lce_io_resp_ready_li)
         );
    end

endmodule

