
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"
`include "bp_be_defines.svh"
`include "bp_top_defines.svh"
`include "bsg_cache.vh"
`include "bsg_noc_links.vh"

module bp_sacc_tile
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 import bp_be_pkg::*;
 import bp_top_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;

 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam io_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(io_noc_flit_width_p)
   , parameter accelerator_type_p = e_sacc_vdp
   )
  (input                                          clk_i
   , input                                        reset_i

   , input [coh_noc_cord_width_p-1:0]             my_cord_i

   , input [coh_noc_ral_link_width_lp-1:0]        lce_req_link_i
   , output logic [coh_noc_ral_link_width_lp-1:0] lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]        lce_fill_link_i
   , output logic [coh_noc_ral_link_width_lp-1:0] lce_fill_link_o

   );

  `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);

  // LCE-CCE link casts
  `bp_cast_i(bp_coh_ready_and_link_s, lce_req_link);
  `bp_cast_o(bp_coh_ready_and_link_s, lce_req_link);
  `bp_cast_i(bp_coh_ready_and_link_s, lce_fill_link);
  `bp_cast_o(bp_coh_ready_and_link_s, lce_fill_link);

  // I/O Link to LCE connections
  bp_bedrock_mem_header_s lce_io_cmd_header_li;
  logic [acache_fill_width_p-1:0] lce_io_cmd_data_li;
  logic lce_io_cmd_header_v_li, lce_io_cmd_has_data_li, lce_io_cmd_header_ready_and_lo;
  logic lce_io_cmd_data_v_li, lce_io_cmd_last_li, lce_io_cmd_data_ready_and_lo;

  bp_bedrock_mem_header_s lce_io_resp_header_lo;
  logic [acache_fill_width_p-1:0] lce_io_resp_data_lo;
  logic lce_io_resp_header_v_lo, lce_io_resp_has_data_lo, lce_io_resp_header_ready_and_li;
  logic lce_io_resp_data_v_lo, lce_io_resp_last_lo, lce_io_resp_data_ready_and_li;

  bp_bedrock_lce_req_header_s lce_lce_req_header_lo;
  logic [acache_fill_width_p-1:0] lce_lce_req_data_lo;
  logic lce_lce_req_header_v_lo, lce_lce_req_has_data_lo, lce_lce_req_header_ready_and_li;
  logic lce_lce_req_data_v_lo, lce_lce_req_last_lo, lce_lce_req_data_ready_and_li;

  bp_bedrock_lce_fill_header_s lce_lce_fill_header_li;
  logic [acache_fill_width_p-1:0] lce_lce_fill_data_li;
  logic lce_lce_fill_header_v_li, lce_lce_fill_has_data_li, lce_lce_fill_header_ready_and_lo;
  logic lce_lce_fill_data_v_li, lce_lce_fill_last_li, lce_lce_fill_data_ready_and_lo;

  // I/O CCE connections
  bp_bedrock_lce_fill_header_s cce_lce_fill_header_lo;
  logic [acache_fill_width_p-1:0] cce_lce_fill_data_lo;
  logic cce_lce_fill_header_v_lo, cce_lce_fill_has_data_lo, cce_lce_fill_header_ready_and_li;
  logic cce_lce_fill_data_v_lo, cce_lce_fill_last_lo, cce_lce_fill_data_ready_and_li;

  bp_bedrock_lce_req_header_s cce_lce_req_header_li;
  logic [acache_fill_width_p-1:0] cce_lce_req_data_li;
  logic cce_lce_req_header_v_li, cce_lce_req_has_data_li, cce_lce_req_header_ready_and_lo;
  logic cce_lce_req_data_v_li, cce_lce_req_last_li, cce_lce_req_data_ready_and_lo;

  bp_bedrock_mem_header_s cce_io_cmd_header_lo;
  logic [acache_fill_width_p-1:0] cce_io_cmd_data_lo;
  logic cce_io_cmd_header_v_lo, cce_io_cmd_has_data_lo, cce_io_cmd_header_ready_and_li;
  logic cce_io_cmd_data_v_lo, cce_io_cmd_last_lo, cce_io_cmd_data_ready_and_li;

  bp_bedrock_mem_header_s cce_io_resp_header_li;
  logic [acache_fill_width_p-1:0] cce_io_resp_data_li;
  logic cce_io_resp_header_v_li, cce_io_resp_has_data_li, cce_io_resp_header_ready_and_lo;
  logic cce_io_resp_data_v_li, cce_io_resp_last_li, cce_io_resp_data_ready_and_lo;

  logic reset_r;
  always_ff @(posedge clk_i)
    reset_r <= reset_i;

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
     ,.reset_i(reset_r)

     ,.lce_id_i(lce_id_li)

     ,.io_cmd_header_i(lce_io_cmd_header_li)
     ,.io_cmd_header_v_i(lce_io_cmd_header_v_li)
     ,.io_cmd_header_ready_and_o(lce_io_cmd_header_ready_and_lo)
     ,.io_cmd_has_data_i(lce_io_cmd_has_data_li)
     ,.io_cmd_data_i(lce_io_cmd_data_li)
     ,.io_cmd_data_v_i(lce_io_cmd_data_v_li)
     ,.io_cmd_data_ready_and_o(lce_io_cmd_data_ready_and_lo)
     ,.io_cmd_last_i(lce_io_cmd_last_li)

     ,.io_resp_header_o(lce_io_resp_header_lo)
     ,.io_resp_header_v_o(lce_io_resp_header_v_lo)
     ,.io_resp_header_ready_and_i(lce_io_resp_header_ready_and_li)
     ,.io_resp_has_data_o(lce_io_resp_has_data_lo)
     ,.io_resp_data_o(lce_io_resp_data_lo)
     ,.io_resp_data_v_o(lce_io_resp_data_v_lo)
     ,.io_resp_data_ready_and_i(lce_io_resp_data_ready_and_li)
     ,.io_resp_last_o(lce_io_resp_last_lo)

     ,.lce_req_header_o(lce_lce_req_header_lo)
     ,.lce_req_header_v_o(lce_lce_req_header_v_lo)
     ,.lce_req_header_ready_and_i(lce_lce_req_header_ready_and_li)
     ,.lce_req_has_data_o(lce_lce_req_has_data_lo)
     ,.lce_req_data_o(lce_lce_req_data_lo)
     ,.lce_req_data_v_o(lce_lce_req_data_v_lo)
     ,.lce_req_data_ready_and_i(lce_lce_req_data_ready_and_li)
     ,.lce_req_last_o(lce_lce_req_last_lo)

     ,.lce_fill_header_i(lce_lce_fill_header_li)
     ,.lce_fill_header_v_i(lce_lce_fill_header_v_li)
     ,.lce_fill_header_ready_and_o(lce_lce_fill_header_ready_and_lo)
     ,.lce_fill_has_data_i(lce_lce_fill_has_data_li)
     ,.lce_fill_data_i(lce_lce_fill_data_li)
     ,.lce_fill_data_v_i(lce_lce_fill_data_v_li)
     ,.lce_fill_data_ready_and_o(lce_lce_fill_data_ready_and_lo)
     ,.lce_fill_last_i(lce_lce_fill_last_li)
     );

  bp_io_cce
   #(.bp_params_p(bp_params_p))
   io_cce
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.cce_id_i(cce_id_li)
     ,.did_i('0)

     ,.lce_req_header_i(cce_lce_req_header_li)
     ,.lce_req_header_v_i(cce_lce_req_header_v_li)
     ,.lce_req_header_ready_and_o(cce_lce_req_header_ready_and_lo)
     ,.lce_req_has_data_i(cce_lce_req_has_data_li)
     ,.lce_req_data_i(cce_lce_req_data_li)
     ,.lce_req_data_v_i(cce_lce_req_data_v_li)
     ,.lce_req_data_ready_and_o(cce_lce_req_data_ready_and_lo)
     ,.lce_req_last_i(cce_lce_req_last_li)

     ,.lce_fill_header_o(cce_lce_fill_header_lo)
     ,.lce_fill_header_v_o(cce_lce_fill_header_v_lo)
     ,.lce_fill_header_ready_and_i(cce_lce_fill_header_ready_and_li)
     ,.lce_fill_has_data_o(cce_lce_fill_has_data_lo)
     ,.lce_fill_data_o(cce_lce_fill_data_lo)
     ,.lce_fill_data_v_o(cce_lce_fill_data_v_lo)
     ,.lce_fill_data_ready_and_i(cce_lce_fill_data_ready_and_li)
     ,.lce_fill_last_o(cce_lce_fill_last_lo)

     ,.io_cmd_header_o(cce_io_cmd_header_lo)
     ,.io_cmd_header_v_o(cce_io_cmd_header_v_lo)
     ,.io_cmd_header_ready_and_i(cce_io_cmd_header_ready_and_li)
     ,.io_cmd_has_data_o(cce_io_cmd_has_data_lo)
     ,.io_cmd_data_o(cce_io_cmd_data_lo)
     ,.io_cmd_data_v_o(cce_io_cmd_data_v_lo)
     ,.io_cmd_data_ready_and_i(cce_io_cmd_data_ready_and_li)
     ,.io_cmd_last_o(cce_io_cmd_last_lo)

     ,.io_resp_header_i(cce_io_resp_header_li)
     ,.io_resp_header_v_i(cce_io_resp_header_v_li)
     ,.io_resp_header_ready_and_o(cce_io_resp_header_ready_and_lo)
     ,.io_resp_has_data_i(cce_io_resp_has_data_li)
     ,.io_resp_data_i(cce_io_resp_data_li)
     ,.io_resp_data_v_i(cce_io_resp_data_v_li)
     ,.io_resp_data_ready_and_o(cce_io_resp_data_ready_and_lo)
     ,.io_resp_last_i(cce_io_resp_last_li)
     );

  bp_bedrock_mem_header_s b2s_io_cmd_header_lo;
  logic [acache_fill_width_p-1:0] b2s_io_cmd_data_lo;
  logic b2s_io_cmd_v_lo, b2s_io_cmd_ready_and_li, b2s_io_cmd_last_lo;

  bp_bedrock_mem_header_s s2b_io_resp_header_li;
  logic [acache_fill_width_p-1:0] s2b_io_resp_data_li;
  logic s2b_io_resp_v_li, s2b_io_resp_ready_and_lo, s2b_io_resp_last_li;

  bp_me_burst_to_stream
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(acache_fill_width_p)
     ,.payload_width_p(mem_payload_width_lp)
     ,.block_width_p(acache_block_width_p)
     ,.payload_mask_p(mem_cmd_payload_mask_gp)
     )
    io_cmd_b2s
     (.clk_i(clk_i)
      ,.reset_i(reset_r)

      ,.in_msg_header_i(cce_io_cmd_header_lo)
      ,.in_msg_header_v_i(cce_io_cmd_header_v_lo)
      ,.in_msg_header_ready_and_o(cce_io_cmd_header_ready_and_li)
      ,.in_msg_has_data_i(cce_io_cmd_has_data_lo)

      ,.in_msg_data_i(cce_io_cmd_data_lo)
      ,.in_msg_data_v_i(cce_io_cmd_data_v_lo)
      ,.in_msg_data_ready_and_o(cce_io_cmd_data_ready_and_li)
      ,.in_msg_last_i(cce_io_cmd_last_lo)

      ,.out_msg_header_o(b2s_io_cmd_header_lo)
      ,.out_msg_data_o(b2s_io_cmd_data_lo)
      ,.out_msg_v_o(b2s_io_cmd_v_lo)
      ,.out_msg_ready_and_i(b2s_io_cmd_ready_and_li)
      ,.out_msg_last_o(b2s_io_cmd_last_lo)
      );

  bp_me_stream_to_burst
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(acache_fill_width_p)
     ,.payload_width_p(mem_payload_width_lp)
     ,.payload_mask_p(mem_resp_payload_mask_gp)
     )
    io_resp_s2b
     (.clk_i(clk_i)
      ,.reset_i(reset_r)

      ,.in_msg_header_i(s2b_io_resp_header_li)
      ,.in_msg_data_i(s2b_io_resp_data_li)
      ,.in_msg_v_i(s2b_io_resp_v_li)
      ,.in_msg_ready_and_o(s2b_io_resp_ready_and_lo)
      ,.in_msg_last_i(s2b_io_resp_last_li)

      ,.out_msg_header_o(cce_io_resp_header_li)
      ,.out_msg_header_v_o(cce_io_resp_header_v_li)
      ,.out_msg_header_ready_and_i(cce_io_resp_header_ready_and_lo)
      ,.out_msg_has_data_o(cce_io_resp_has_data_li)

      ,.out_msg_data_o(cce_io_resp_data_li)
      ,.out_msg_data_v_o(cce_io_resp_data_v_li)
      ,.out_msg_data_ready_and_i(cce_io_resp_data_ready_and_lo)
      ,.out_msg_last_o(cce_io_resp_last_li)
      );

  if (sacc_type_p == e_sacc_vdp) begin : sacc_vdp
    bp_sacc_vdp
     #(.bp_params_p(bp_params_p))
     accelerator
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.lce_id_i(lce_id_li)

       ,.io_cmd_header_i(b2s_io_cmd_header_lo)
       ,.io_cmd_data_i(b2s_io_cmd_data_lo)
       ,.io_cmd_v_i(b2s_io_cmd_v_lo)
       ,.io_cmd_last_i(b2s_io_cmd_last_lo)
       ,.io_cmd_ready_and_o(b2s_io_cmd_ready_and_li)

       ,.io_resp_header_o(s2b_io_resp_header_li)
       ,.io_resp_data_o(s2b_io_resp_data_li)
       ,.io_resp_v_o(s2b_io_resp_v_li)
       ,.io_resp_last_o(s2b_io_resp_last_li)
       ,.io_resp_ready_and_i(s2b_io_resp_ready_and_lo)
       );
  end
  else if (sacc_type_p == e_sacc_loopback) begin: sacc_loopback
    bp_sacc_loopback
     #(.bp_params_p(bp_params_p))
     accelerator
      (.clk_i(clk_i)
       ,.reset_i(reset_r)

       ,.lce_id_i(lce_id_li)

       ,.io_cmd_header_i(b2s_io_cmd_header_lo)
       ,.io_cmd_data_i(b2s_io_cmd_data_lo)
       ,.io_cmd_v_i(b2s_io_cmd_v_lo)
       ,.io_cmd_last_i(b2s_io_cmd_last_lo)
       ,.io_cmd_ready_and_o(b2s_io_cmd_ready_and_li)

       ,.io_resp_header_o(s2b_io_resp_header_li)
       ,.io_resp_data_o(s2b_io_resp_data_li)
       ,.io_resp_v_o(s2b_io_resp_v_li)
       ,.io_resp_last_o(s2b_io_resp_last_li)
       ,.io_resp_ready_and_i(s2b_io_resp_ready_and_lo)
       );
  end
  else begin : none
    assign b2s_io_cmd_ready_and_li = 1'b0;
    assign s2b_io_resp_header_li = '0;
    assign s2b_io_resp_data_li = '0;
    assign s2b_io_resp_v_li = 1'b0;
    assign s2b_io_resp_last_li = 1'b0;
  end

  // TODO: WH-Burst converters
  `declare_bp_lce_req_wormhole_header_s(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, bp_bedrock_lce_req_header_s);
  localparam lce_req_wh_pad_width_lp = `bp_bedrock_wormhole_packet_pad_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, $bits(bp_bedrock_lce_req_header_s));
  bp_lce_req_wormhole_header_s lce_req_wh_header_lo;

  `declare_bp_lce_fill_wormhole_header_s(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, bp_bedrock_lce_fill_header_s);
  localparam lce_fill_wh_pad_width_lp = `bp_bedrock_wormhole_packet_pad_width(coh_noc_flit_width_p, coh_noc_cord_width_p, coh_noc_len_width_p, coh_noc_cid_width_p, $bits(bp_bedrock_lce_fill_header_s));
  bp_lce_fill_wormhole_header_s cce_lce_fill_wh_header_lo;

  localparam bedrock_len_width_lp = `BSG_SAFE_CLOG2(`BSG_CDIV((1<<e_bedrock_msg_size_128)*8,acache_fill_width_p));

  // Burst to WH (lce_lce_req_header_lo)
  bp_me_wormhole_packet_encode_lce_req
   #(.bp_params_p(bp_params_p)
     )
   req_encode
    (.lce_req_header_i(lce_lce_req_header_lo)
     ,.wh_header_o(lce_req_wh_header_lo)
     );

  bp_me_burst_to_wormhole
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_req_header_width_lp)
     ,.pr_data_width_p(acache_fill_width_p)
     )
   lce_req_burst_to_wh
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.pr_hdr_i(lce_req_wh_header_lo[0+:($bits(bp_lce_req_wormhole_header_s)-lce_req_wh_pad_width_lp)])
    ,.pr_hdr_v_i(lce_lce_req_header_v_lo)
    ,.pr_hdr_ready_and_o(lce_lce_req_header_ready_and_li)
    ,.pr_has_data_i(lce_lce_req_has_data_lo)

    ,.pr_data_i(lce_lce_req_data_lo)
    ,.pr_data_v_i(lce_lce_req_data_v_lo)
    ,.pr_data_ready_and_o(lce_lce_req_data_ready_and_li)
    ,.pr_last_i(lce_lce_req_last_lo)

    ,.link_data_o(lce_req_link_cast_o.data)
    ,.link_v_o(lce_req_link_cast_o.v)
    ,.link_ready_and_i(lce_req_link_cast_i.ready_and_rev)
    );

  // WH to Burst (lce_lce_fill_header_li)
  logic [bedrock_len_width_lp-1:0] lce_fill_pr_len;
  bp_bedrock_size_to_len
   #(.len_width_p(bedrock_len_width_lp)
     ,.beat_width_p(acache_fill_width_p)
     )
   lce_fill_size_to_len
   (.size_i(lce_lce_fill_header_li.size)
    ,.len_o(lce_fill_pr_len)
   );

  bp_me_wormhole_to_burst
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_fill_header_width_lp)
     ,.pr_data_width_p(acache_fill_width_p)
     ,.pr_len_width_p(bedrock_len_width_lp)
     )
   lce_fill_wh_to_burst
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_data_i(lce_fill_link_cast_i.data)
    ,.link_v_i(lce_fill_link_cast_i.v)
    ,.link_ready_and_o(lce_fill_link_cast_o.ready_and_rev)

    ,.pr_hdr_o(lce_lce_fill_header_li)
    ,.pr_hdr_v_o(lce_lce_fill_header_v_li)
    ,.pr_hdr_ready_and_i(lce_lce_fill_header_ready_and_lo)
    ,.pr_has_data_o(lce_lce_fill_has_data_li)
    ,.pr_data_beats_i(lce_fill_pr_len)

    ,.pr_data_o(lce_lce_fill_data_li)
    ,.pr_data_v_o(lce_lce_fill_data_v_li)
    ,.pr_data_ready_and_i(lce_lce_fill_data_ready_and_lo)
    ,.pr_last_o(lce_lce_fill_last_li)
    );

  // WH to Burst (cce_lce_req_header_li)
  logic [bedrock_len_width_lp-1:0] cce_lce_req_pr_len;
  bp_bedrock_size_to_len
   #(.len_width_p(bedrock_len_width_lp)
     ,.beat_width_p(acache_fill_width_p)
     )
   cce_lce_req_size_to_len
   (.size_i(cce_lce_req_header_li.size)
    ,.len_o(cce_lce_req_pr_len)
   );

  bp_me_wormhole_to_burst
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_req_header_width_lp)
     ,.pr_data_width_p(acache_fill_width_p)
     ,.pr_len_width_p(bedrock_len_width_lp)
     )
   cce_lce_req_wh_to_burst
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_data_i(lce_req_link_cast_i.data)
    ,.link_v_i(lce_req_link_cast_i.v)
    ,.link_ready_and_o(lce_req_link_cast_o.ready_and_rev)

    ,.pr_hdr_o(cce_lce_req_header_li)
    ,.pr_hdr_v_o(cce_lce_req_header_v_li)
    ,.pr_hdr_ready_and_i(cce_lce_req_header_ready_and_lo)
    ,.pr_has_data_o(cce_lce_req_has_data_li)
    ,.pr_data_beats_i(cce_lce_req_pr_len)

    ,.pr_data_o(cce_lce_req_data_li)
    ,.pr_data_v_o(cce_lce_req_data_v_li)
    ,.pr_data_ready_and_i(cce_lce_req_data_ready_and_lo)
    ,.pr_last_o(cce_lce_req_last_li)
    );

  // Burst to WH (cce_lce_fill_header_lo)
  bp_me_wormhole_packet_encode_lce_fill
   #(.bp_params_p(bp_params_p))
   cce_fill_encode
    (.lce_fill_header_i(cce_lce_fill_header_lo)
     ,.wh_header_o(cce_lce_fill_wh_header_lo)
     );

  bp_me_burst_to_wormhole
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_fill_header_width_lp)
     ,.pr_data_width_p(acache_fill_width_p)
     )
   cce_lce_fill_burst_to_wh
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.pr_hdr_i(cce_lce_fill_wh_header_lo[0+:($bits(bp_lce_fill_wormhole_header_s)-lce_fill_wh_pad_width_lp)])
    ,.pr_hdr_v_i(cce_lce_fill_header_v_lo)
    ,.pr_hdr_ready_and_o(cce_lce_fill_header_ready_and_li)
    ,.pr_has_data_i(cce_lce_fill_has_data_lo)

    ,.pr_data_i(cce_lce_fill_data_lo)
    ,.pr_data_v_i(cce_lce_fill_data_v_lo)
    ,.pr_data_ready_and_o(cce_lce_fill_data_ready_and_li)
    ,.pr_last_i(cce_lce_fill_last_lo)

    ,.link_data_o(lce_fill_link_cast_o.data)
    ,.link_v_o(lce_fill_link_cast_o.v)
    ,.link_ready_and_i(lce_fill_link_cast_i.ready_and_rev)
    );

endmodule

