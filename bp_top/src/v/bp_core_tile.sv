/**
 *
 * bp_core_tile.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"
`include "bsg_cache.svh"
`include "bsg_noc_links.svh"

module bp_core_tile
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bp_top_pkg::*;
 import bsg_cache_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p)

   // Wormhole parameters
   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam dma_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(dma_noc_flit_width_p)
   )
  (input                                                      clk_i
   , input                                                    rt_clk_i
   , input                                                    reset_i

   // Memory side connection
   , input [mem_noc_did_width_p-1:0]                          my_did_i
   , input [mem_noc_did_width_p-1:0]                          host_did_i
   , input [coh_noc_cord_width_p-1:0]                         my_cord_i

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_req_link_i
   , output logic [coh_noc_ral_link_width_lp-1:0]             lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_cmd_link_i
   , output logic [coh_noc_ral_link_width_lp-1:0]             lce_cmd_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_fill_link_i
   , output logic [coh_noc_ral_link_width_lp-1:0]             lce_fill_link_o

   , input [coh_noc_ral_link_width_lp-1:0]                    lce_resp_link_i
   , output logic [coh_noc_ral_link_width_lp-1:0]             lce_resp_link_o

   , output logic [dma_noc_ral_link_width_lp-1:0]             dma_link_o
   , input [dma_noc_ral_link_width_lp-1:0]                    dma_link_i
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(dma_noc_flit_width_p, bp_dma_ready_and_link_s);

  // Reset
  logic reset_r;
  always_ff @(posedge clk_i)
    reset_r <= reset_i;

  // LCE-CCE coherence network links
  `bp_cast_i(bp_coh_ready_and_link_s, lce_req_link);
  `bp_cast_o(bp_coh_ready_and_link_s, lce_req_link);
  `bp_cast_i(bp_coh_ready_and_link_s, lce_cmd_link);
  `bp_cast_o(bp_coh_ready_and_link_s, lce_cmd_link);
  `bp_cast_i(bp_coh_ready_and_link_s, lce_fill_link);
  `bp_cast_o(bp_coh_ready_and_link_s, lce_fill_link);
  `bp_cast_i(bp_coh_ready_and_link_s, lce_resp_link);
  `bp_cast_o(bp_coh_ready_and_link_s, lce_resp_link);

  // Core-side LCE-CCE network connections
  bp_bedrock_lce_req_header_s [1:0] lce_req_header_lo;
  logic [1:0][bedrock_fill_width_p-1:0] lce_req_data_lo;
  logic [1:0] lce_req_v_lo, lce_req_ready_and_li;
  logic [1:0][coh_noc_cord_width_p-1:0] lce_req_dst_cord_lo;
  logic [1:0][coh_noc_cid_width_p-1:0] lce_req_dst_cid_lo;

  bp_bedrock_lce_cmd_header_s [1:0] lce_cmd_header_li;
  logic [1:0][bedrock_fill_width_p-1:0] lce_cmd_data_li;
  logic [1:0] lce_cmd_v_li, lce_cmd_ready_and_lo;

  bp_bedrock_lce_fill_header_s [1:0] lce_fill_header_li;
  logic [1:0][bedrock_fill_width_p-1:0] lce_fill_data_li;
  logic [1:0] lce_fill_v_li, lce_fill_ready_and_lo;

  bp_bedrock_lce_fill_header_s [1:0] lce_fill_header_lo;
  logic [1:0][bedrock_fill_width_p-1:0] lce_fill_data_lo;
  logic [1:0] lce_fill_v_lo, lce_fill_ready_and_li;
  logic [1:0][coh_noc_cord_width_p-1:0] lce_fill_dst_cord_lo;
  logic [1:0][coh_noc_cid_width_p-1:0] lce_fill_dst_cid_lo;

  bp_bedrock_lce_resp_header_s [1:0] lce_resp_header_lo;
  logic [1:0][bedrock_fill_width_p-1:0] lce_resp_data_lo;
  logic [1:0] lce_resp_v_lo, lce_resp_ready_and_li;
  logic [1:0][coh_noc_cord_width_p-1:0] lce_resp_dst_cord_lo;
  logic [1:0][coh_noc_cid_width_p-1:0] lce_resp_dst_cid_lo;

  // CCE-side LCE-CCE BedRock network
  bp_bedrock_lce_req_header_s lce_req_header_li;
  logic [bedrock_fill_width_p-1:0] lce_req_data_li;
  logic lce_req_v_li, lce_req_ready_and_lo;

  bp_bedrock_lce_resp_header_s lce_resp_header_li;
  logic [bedrock_fill_width_p-1:0] lce_resp_data_li;
  logic lce_resp_v_li, lce_resp_ready_and_lo;

  bp_bedrock_lce_cmd_header_s lce_cmd_header_lo;
  logic [bedrock_fill_width_p-1:0] lce_cmd_data_lo;
  logic lce_cmd_v_lo, lce_cmd_ready_and_li;
  logic [coh_noc_cord_width_p-1:0] lce_cmd_dst_cord_lo;
  logic [coh_noc_cid_width_p-1:0] lce_cmd_dst_cid_lo;

  // LCE-CCE network links - unconcentrated
  bp_coh_ready_and_link_s [1:0] lce_req_link_li, lce_req_link_lo;
  bp_coh_ready_and_link_s [1:0] lce_cmd_link_li, lce_cmd_link_lo;
  bp_coh_ready_and_link_s [1:0] lce_fill_link_li, lce_fill_link_lo;
  bp_coh_ready_and_link_s [1:0] lce_resp_link_li, lce_resp_link_lo;

  bp_coh_ready_and_link_s cce_lce_req_link_lo;
  bp_coh_ready_and_link_s cce_lce_resp_link_lo;

  // stub unused CCE link connections
  // CCE does not send requests
  assign cce_lce_req_link_lo.v = '0;
  assign cce_lce_req_link_lo.data = '0;
  // CCE does not send responses
  assign cce_lce_resp_link_lo.v = '0;
  assign cce_lce_resp_link_lo.data = '0;

  for (genvar i = 0; i < 2; i++) begin : lce

    // LCE request from LCE
    bp_me_cce_id_to_cord
     #(.bp_params_p(bp_params_p))
     req_router_cord
      (.cce_id_i(lce_req_header_lo[i].payload.dst_id)
       ,.cce_cord_o(lce_req_dst_cord_lo[i])
       ,.cce_cid_o(lce_req_dst_cid_lo[i])
       );

    bp_me_stream_to_wormhole
     #(.bp_params_p(bp_params_p)
       ,.flit_width_p(coh_noc_flit_width_p)
       ,.cord_width_p(coh_noc_cord_width_p)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cid_width_p(coh_noc_cid_width_p)
       ,.pr_hdr_width_p(lce_req_header_width_lp)
       ,.pr_payload_width_p(lce_req_payload_width_lp)
       ,.pr_stream_mask_p(lce_req_stream_mask_gp)
       ,.pr_data_width_p(bedrock_fill_width_p)
       )
     lce_req_stream_to_wh
     (.clk_i(clk_i)
      ,.reset_i(reset_r)

      ,.pr_hdr_i(lce_req_header_lo[i])
      ,.pr_data_i(lce_req_data_lo[i])
      ,.pr_v_i(lce_req_v_lo[i])
      ,.pr_ready_and_o(lce_req_ready_and_li[i])
      ,.dst_cord_i(lce_req_dst_cord_lo[i])
      ,.dst_cid_i(lce_req_dst_cid_lo[i])

      ,.link_data_o(lce_req_link_lo[i].data)
      ,.link_v_o(lce_req_link_lo[i].v)
      ,.link_ready_and_i(lce_req_link_li[i].ready_and_rev)
      );
    // LCE does not receive requests
    assign lce_req_link_lo[i].ready_and_rev = 1'b0;

    // LCE command to LCE
    bp_me_wormhole_to_stream
     #(.bp_params_p(bp_params_p)
       ,.flit_width_p(coh_noc_flit_width_p)
       ,.cord_width_p(coh_noc_cord_width_p)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cid_width_p(coh_noc_cid_width_p)
       ,.pr_hdr_width_p(lce_cmd_header_width_lp)
       ,.pr_payload_width_p(lce_cmd_payload_width_lp)
       ,.pr_stream_mask_p(lce_cmd_stream_mask_gp)
       ,.pr_data_width_p(bedrock_fill_width_p)
       )
     lce_cmd_wh_to_stream
     (.clk_i(clk_i)
      ,.reset_i(reset_r)

      ,.link_data_i(lce_cmd_link_li[i].data)
      ,.link_v_i(lce_cmd_link_li[i].v)
      ,.link_ready_and_o(lce_cmd_link_lo[i].ready_and_rev)

      ,.pr_hdr_o(lce_cmd_header_li[i])
      ,.pr_data_o(lce_cmd_data_li[i])
      ,.pr_v_o(lce_cmd_v_li[i])
      ,.pr_ready_and_i(lce_cmd_ready_and_lo[i])
      );
    // LCE does not send commands
    assign lce_cmd_link_lo[i].v = '0;
    assign lce_cmd_link_lo[i].data = '0;

    // LCE fill to LCE
    bp_me_wormhole_to_stream
     #(.bp_params_p(bp_params_p)
       ,.flit_width_p(coh_noc_flit_width_p)
       ,.cord_width_p(coh_noc_cord_width_p)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cid_width_p(coh_noc_cid_width_p)
       ,.pr_hdr_width_p(lce_fill_header_width_lp)
       ,.pr_payload_width_p(lce_fill_payload_width_lp)
       ,.pr_stream_mask_p(lce_fill_stream_mask_gp)
       ,.pr_data_width_p(bedrock_fill_width_p)
       )
     lce_fill_wh_to_stream
     (.clk_i(clk_i)
      ,.reset_i(reset_r)

      ,.link_data_i(lce_fill_link_li[i].data)
      ,.link_v_i(lce_fill_link_li[i].v)
      ,.link_ready_and_o(lce_fill_link_lo[i].ready_and_rev)

      ,.pr_hdr_o(lce_fill_header_li[i])
      ,.pr_data_o(lce_fill_data_li[i])
      ,.pr_v_o(lce_fill_v_li[i])
      ,.pr_ready_and_i(lce_fill_ready_and_lo[i])
      );

    // LCE fill from LCE
    bp_me_lce_id_to_cord
     #(.bp_params_p(bp_params_p))
     fill_router_cord
      (.lce_id_i(lce_fill_header_lo[i].payload.dst_id)
       ,.lce_cord_o(lce_fill_dst_cord_lo[i])
       ,.lce_cid_o(lce_fill_dst_cid_lo[i])
       );

    bp_me_stream_to_wormhole
     #(.bp_params_p(bp_params_p)
       ,.flit_width_p(coh_noc_flit_width_p)
       ,.cord_width_p(coh_noc_cord_width_p)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cid_width_p(coh_noc_cid_width_p)
       ,.pr_hdr_width_p(lce_fill_header_width_lp)
       ,.pr_payload_width_p(lce_fill_payload_width_lp)
       ,.pr_stream_mask_p(lce_fill_stream_mask_gp)
       ,.pr_data_width_p(bedrock_fill_width_p)
       )
     lce_fill_stream_to_wh
     (.clk_i(clk_i)
      ,.reset_i(reset_r)

      ,.pr_hdr_i(lce_fill_header_lo[i])
      ,.pr_data_i(lce_fill_data_lo[i])
      ,.pr_v_i(lce_fill_v_lo[i])
      ,.pr_ready_and_o(lce_fill_ready_and_li[i])
      ,.dst_cord_i(lce_fill_dst_cord_lo[i])
      ,.dst_cid_i(lce_fill_dst_cid_lo[i])

      ,.link_data_o(lce_fill_link_lo[i].data)
      ,.link_v_o(lce_fill_link_lo[i].v)
      ,.link_ready_and_i(lce_fill_link_li[i].ready_and_rev)
      );

    // LCE Response from LCE
    bp_me_cce_id_to_cord
     #(.bp_params_p(bp_params_p))
     resp_router_cord
      (.cce_id_i(lce_resp_header_lo[i].payload.dst_id)
       ,.cce_cord_o(lce_resp_dst_cord_lo[i])
       ,.cce_cid_o(lce_resp_dst_cid_lo[i])
       );

    bp_me_stream_to_wormhole
     #(.bp_params_p(bp_params_p)
       ,.flit_width_p(coh_noc_flit_width_p)
       ,.cord_width_p(coh_noc_cord_width_p)
       ,.len_width_p(coh_noc_len_width_p)
       ,.cid_width_p(coh_noc_cid_width_p)
       ,.pr_hdr_width_p(lce_resp_header_width_lp)
       ,.pr_payload_width_p(lce_resp_payload_width_lp)
       ,.pr_stream_mask_p(lce_resp_stream_mask_gp)
       ,.pr_data_width_p(bedrock_fill_width_p)
       )
     lce_resp_stream_to_wh
     (.clk_i(clk_i)
      ,.reset_i(reset_r)

      ,.pr_hdr_i(lce_resp_header_lo[i])
      ,.pr_data_i(lce_resp_data_lo[i])
      ,.pr_v_i(lce_resp_v_lo[i])
      ,.pr_ready_and_o(lce_resp_ready_and_li[i])
      ,.dst_cord_i(lce_resp_dst_cord_lo[i])
      ,.dst_cid_i(lce_resp_dst_cid_lo[i])

      ,.link_data_o(lce_resp_link_lo[i].data)
      ,.link_v_o(lce_resp_link_lo[i].v)
      ,.link_ready_and_i(lce_resp_link_li[i].ready_and_rev)
      );
    // LCE does not receive responses
    assign lce_resp_link_lo[i].ready_and_rev = 1'b0;

  end // lce to WH network connections

  // LCE to CCE request
  bp_me_wormhole_to_stream
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_req_header_width_lp)
     ,.pr_payload_width_p(lce_req_payload_width_lp)
     ,.pr_stream_mask_p(lce_req_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   lce_req_wh_to_stream
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_data_i(lce_req_link_cast_i.data)
    ,.link_v_i(lce_req_link_cast_i.v)
    ,.link_ready_and_o(cce_lce_req_link_lo.ready_and_rev)

    ,.pr_hdr_o(lce_req_header_li)
    ,.pr_data_o(lce_req_data_li)
    ,.pr_v_o(lce_req_v_li)
    ,.pr_ready_and_i(lce_req_ready_and_lo)
    );

  // CCE to LCE command
  bp_me_lce_id_to_cord
   #(.bp_params_p(bp_params_p))
   cmd_router_cord
    (.lce_id_i(lce_cmd_header_lo.payload.dst_id)
     ,.lce_cord_o(lce_cmd_dst_cord_lo)
     ,.lce_cid_o(lce_cmd_dst_cid_lo)
     );

  bp_me_stream_to_wormhole
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_cmd_header_width_lp)
     ,.pr_payload_width_p(lce_cmd_payload_width_lp)
     ,.pr_stream_mask_p(lce_cmd_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   lce_cmd_stream_to_wh
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.pr_hdr_i(lce_cmd_header_lo)
    ,.pr_data_i(lce_cmd_data_lo)
    ,.pr_v_i(lce_cmd_v_lo)
    ,.pr_ready_and_o(lce_cmd_ready_and_li)
    ,.dst_cord_i(lce_cmd_dst_cord_lo)
    ,.dst_cid_i(lce_cmd_dst_cid_lo)

    ,.link_data_o(lce_cmd_link_cast_o.data)
    ,.link_v_o(lce_cmd_link_cast_o.v)
    ,.link_ready_and_i(lce_cmd_link_cast_i.ready_and_rev)
    );

  // LCE to CCE response
  bp_me_wormhole_to_stream
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(coh_noc_flit_width_p)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.pr_hdr_width_p(lce_resp_header_width_lp)
     ,.pr_payload_width_p(lce_resp_payload_width_lp)
     ,.pr_stream_mask_p(lce_resp_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   lce_resp_wh_to_stream
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_data_i(lce_resp_link_cast_i.data)
    ,.link_v_i(lce_resp_link_cast_i.v)
    ,.link_ready_and_o(cce_lce_resp_link_lo.ready_and_rev)

    ,.pr_hdr_o(lce_resp_header_li)
    ,.pr_data_o(lce_resp_data_li)
    ,.pr_v_o(lce_resp_v_li)
    ,.pr_ready_and_i(lce_resp_ready_and_lo)
    );

  // LCE-CCE Network Concentrators

  bp_coh_ready_and_link_s req_concentrated_link_li, req_concentrated_link_lo;
  bp_coh_ready_and_link_s cmd_concentrated_link_li, cmd_concentrated_link_lo;
  bp_coh_ready_and_link_s fill_concentrated_link_li, fill_concentrated_link_lo;
  bp_coh_ready_and_link_s resp_concentrated_link_li, resp_concentrated_link_lo;

  assign req_concentrated_link_li = lce_req_link_cast_i;
  assign lce_req_link_cast_o = '{data          : req_concentrated_link_lo.data
                                 ,v            : req_concentrated_link_lo.v
                                 ,ready_and_rev: cce_lce_req_link_lo.ready_and_rev
                                 };
  bsg_wormhole_concentrator_in
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.num_in_p(2)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.hold_on_valid_p(1)
     )
   req_concentrator
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.links_v_i({lce_req_link_lo[1].v, lce_req_link_lo[0].v})
     ,.links_data_i({lce_req_link_lo[1].data, lce_req_link_lo[0].data})
     ,.links_ready_and_rev_o({lce_req_link_li[1].ready_and_rev, lce_req_link_li[0].ready_and_rev})

     ,.concentrated_link_v_o(req_concentrated_link_lo.v)
     ,.concentrated_link_data_o(req_concentrated_link_lo.data)
     ,.concentrated_link_ready_and_rev_i(req_concentrated_link_li.ready_and_rev)
     );
  assign lce_req_link_li[1].v = 1'b0;
  assign lce_req_link_li[0].v = 1'b0;
  assign lce_req_link_li[1].data = '0;
  assign lce_req_link_li[0].data = '0;
  assign req_concentrated_link_lo.ready_and_rev = 1'b0;

  assign cmd_concentrated_link_li = lce_cmd_link_cast_i;
  assign lce_cmd_link_cast_o.ready_and_rev = cmd_concentrated_link_lo.ready_and_rev;
  bsg_wormhole_concentrator_out
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.num_in_p(2)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.hold_on_valid_p(1)
     )
   cmd_concentrator
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.links_v_o({lce_cmd_link_li[1].v, lce_cmd_link_li[0].v})
     ,.links_data_o({lce_cmd_link_li[1].data, lce_cmd_link_li[0].data})
     ,.links_ready_and_rev_i({lce_cmd_link_lo[1].ready_and_rev, lce_cmd_link_lo[0].ready_and_rev})

     ,.concentrated_link_v_i(cmd_concentrated_link_li.v)
     ,.concentrated_link_data_i(cmd_concentrated_link_li.data)
     ,.concentrated_link_ready_and_rev_o(cmd_concentrated_link_lo.ready_and_rev)
     );
  assign lce_cmd_link_li[1].ready_and_rev = 1'b0;
  assign lce_cmd_link_li[0].ready_and_rev = 1'b0;
  assign cmd_concentrated_link_lo.v = 1'b0;
  assign cmd_concentrated_link_lo.data = '0;

  assign fill_concentrated_link_li = lce_fill_link_cast_i;
  assign lce_fill_link_cast_o = fill_concentrated_link_lo;
  bsg_wormhole_concentrator
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.cid_width_p(coh_noc_cid_width_p)
     ,.num_in_p(2)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.hold_on_valid_p(1)
     )
   fill_concentrator
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.links_i(lce_fill_link_lo)
     ,.links_o(lce_fill_link_li)

     ,.concentrated_link_i(fill_concentrated_link_li)
     ,.concentrated_link_o(fill_concentrated_link_lo)
     );

  assign resp_concentrated_link_li = lce_resp_link_cast_i;
  assign lce_resp_link_cast_o = '{data          : resp_concentrated_link_lo.data
                                  ,v            : resp_concentrated_link_lo.v
                                  ,ready_and_rev: cce_lce_resp_link_lo.ready_and_rev
                                  };
  bsg_wormhole_concentrator_in
   #(.flit_width_p(coh_noc_flit_width_p)
     ,.len_width_p(coh_noc_len_width_p)
     ,.num_in_p(2)
     ,.cord_width_p(coh_noc_cord_width_p)
     ,.hold_on_valid_p(1)
     )
   resp_concentrator
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.links_v_i({lce_resp_link_lo[1].v, lce_resp_link_lo[0].v})
     ,.links_data_i({lce_resp_link_lo[1].data, lce_resp_link_lo[0].data})
     ,.links_ready_and_rev_o({lce_resp_link_li[1].ready_and_rev, lce_resp_link_li[0].ready_and_rev})

     ,.concentrated_link_v_o(resp_concentrated_link_lo.v)
     ,.concentrated_link_data_o(resp_concentrated_link_lo.data)
     ,.concentrated_link_ready_and_rev_i(resp_concentrated_link_li.ready_and_rev)
     );
  assign lce_resp_link_li[1].v = 1'b0;
  assign lce_resp_link_li[0].v = 1'b0;
  assign lce_resp_link_li[1].data = '0;
  assign lce_resp_link_li[0].data = '0;
  assign resp_concentrated_link_lo.ready_and_rev = 1'b0;

  // Processor
  bp_cfg_bus_s cfg_bus_lo;
  logic cce_ucode_v_lo;
  logic cce_ucode_w_lo;
  logic [cce_pc_width_p-1:0] cce_ucode_addr_lo;
  logic [cce_instr_width_gp-1:0] cce_ucode_data_lo, cce_ucode_data_li;

  bp_bedrock_mem_fwd_header_s mem_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_lo;
  logic mem_fwd_v_lo, mem_fwd_ready_and_li;
  bp_bedrock_mem_rev_header_s mem_rev_header_li;
  logic [bedrock_fill_width_p-1:0] mem_rev_data_li;
  logic mem_rev_v_li, mem_rev_ready_and_lo;

  `declare_bsg_cache_dma_pkt_s(daddr_width_p, l2_block_size_in_words_p);
  bsg_cache_dma_pkt_s [l2_dmas_p-1:0] dma_pkt_lo;
  logic [l2_dmas_p-1:0] dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [l2_dmas_p-1:0][l2_fill_width_p-1:0] dma_data_li;
  logic [l2_dmas_p-1:0] dma_data_v_li, dma_data_ready_and_lo;
  logic [l2_dmas_p-1:0][l2_fill_width_p-1:0] dma_data_lo;
  logic [l2_dmas_p-1:0] dma_data_v_lo, dma_data_yumi_li;
  bp_core
   #(.bp_params_p(bp_params_p))
   core
    (.clk_i(clk_i)
     ,.rt_clk_i(rt_clk_i)
     ,.reset_i(reset_r)

     ,.my_did_i(my_did_i)
     ,.host_did_i(host_did_i)
     ,.my_cord_i(my_cord_i)

     ,.cfg_bus_o(cfg_bus_lo)
     ,.cce_ucode_v_o(cce_ucode_v_lo)
     ,.cce_ucode_w_o(cce_ucode_w_lo)
     ,.cce_ucode_addr_o(cce_ucode_addr_lo)
     ,.cce_ucode_data_o(cce_ucode_data_lo)
     ,.cce_ucode_data_i(cce_ucode_data_li)

     ,.lce_req_header_o(lce_req_header_lo)
     ,.lce_req_data_o(lce_req_data_lo)
     ,.lce_req_v_o(lce_req_v_lo)
     ,.lce_req_ready_and_i(lce_req_ready_and_li)

     ,.lce_cmd_header_i(lce_cmd_header_li)
     ,.lce_cmd_data_i(lce_cmd_data_li)
     ,.lce_cmd_v_i(lce_cmd_v_li)
     ,.lce_cmd_ready_and_o(lce_cmd_ready_and_lo)

     ,.lce_resp_header_o(lce_resp_header_lo)
     ,.lce_resp_data_o(lce_resp_data_lo)
     ,.lce_resp_v_o(lce_resp_v_lo)
     ,.lce_resp_ready_and_i(lce_resp_ready_and_li)

     ,.lce_fill_header_i(lce_fill_header_li)
     ,.lce_fill_data_i(lce_fill_data_li)
     ,.lce_fill_v_i(lce_fill_v_li)
     ,.lce_fill_ready_and_o(lce_fill_ready_and_lo)

     ,.lce_fill_header_o(lce_fill_header_lo)
     ,.lce_fill_data_o(lce_fill_data_lo)
     ,.lce_fill_v_o(lce_fill_v_lo)
     ,.lce_fill_ready_and_i(lce_fill_ready_and_li)

     ,.mem_fwd_header_i(mem_fwd_header_lo)
     ,.mem_fwd_data_i(mem_fwd_data_lo)
     ,.mem_fwd_v_i(mem_fwd_v_lo)
     ,.mem_fwd_ready_and_o(mem_fwd_ready_and_li)

     ,.mem_rev_header_o(mem_rev_header_li)
     ,.mem_rev_data_o(mem_rev_data_li)
     ,.mem_rev_v_o(mem_rev_v_li)
     ,.mem_rev_ready_and_i(mem_rev_ready_and_lo)

     ,.dma_pkt_o(dma_pkt_lo)
     ,.dma_pkt_v_o(dma_pkt_v_lo)
     ,.dma_pkt_ready_and_i(dma_pkt_yumi_li)

     ,.dma_data_i(dma_data_li)
     ,.dma_data_v_i(dma_data_v_li)
     ,.dma_data_ready_and_o(dma_data_ready_and_lo)

     ,.dma_data_o(dma_data_lo)
     ,.dma_data_v_o(dma_data_v_lo)
     ,.dma_data_ready_and_i(dma_data_yumi_li)
     );

  // CCE: Cache Coherence Engine
  bp_cce_wrapper
   #(.bp_params_p(bp_params_p))
   cce
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.cfg_bus_i(cfg_bus_lo)

     ,.ucode_v_i(cce_ucode_v_lo)
     ,.ucode_w_i(cce_ucode_w_lo)
     ,.ucode_addr_i(cce_ucode_addr_lo)
     ,.ucode_data_i(cce_ucode_data_lo)
     ,.ucode_data_o(cce_ucode_data_li)

     // LCE-CCE Interface
     // BedRock Burst protocol: ready&valid
     ,.lce_req_header_i(lce_req_header_li)
     ,.lce_req_data_i(lce_req_data_li)
     ,.lce_req_v_i(lce_req_v_li)
     ,.lce_req_ready_and_o(lce_req_ready_and_lo)

     ,.lce_resp_header_i(lce_resp_header_li)
     ,.lce_resp_data_i(lce_resp_data_li)
     ,.lce_resp_v_i(lce_resp_v_li)
     ,.lce_resp_ready_and_o(lce_resp_ready_and_lo)

     ,.lce_cmd_header_o(lce_cmd_header_lo)
     ,.lce_cmd_data_o(lce_cmd_data_lo)
     ,.lce_cmd_v_o(lce_cmd_v_lo)
     ,.lce_cmd_ready_and_i(lce_cmd_ready_and_li)

     // CCE-MEM Interface
     // BedRock Burst protocol: ready&valid
     ,.mem_rev_header_i(mem_rev_header_li)
     ,.mem_rev_data_i(mem_rev_data_li)
     ,.mem_rev_v_i(mem_rev_v_li)
     ,.mem_rev_ready_and_o(mem_rev_ready_and_lo)

     ,.mem_fwd_header_o(mem_fwd_header_lo)
     ,.mem_fwd_data_o(mem_fwd_data_lo)
     ,.mem_fwd_v_o(mem_fwd_v_lo)
     ,.mem_fwd_ready_and_i(mem_fwd_ready_and_li)
     );

  bp_dma_ready_and_link_s [l2_dmas_p-1:0] dma_link_lo, dma_link_li;
  for (genvar i = 0; i < l2_dmas_p; i++)
    begin : dma
      wire [dma_noc_cord_width_p-1:0] cord_li = my_cord_i[coh_noc_x_cord_width_p+:dma_noc_y_cord_width_p];
      wire [dma_noc_cid_width_p-1:0]   cid_li = i;

      bsg_cache_dma_to_wormhole
       #(.dma_addr_width_p(daddr_width_p)
         ,.dma_burst_len_p(l2_block_size_in_fill_p)
         ,.dma_mask_width_p(l2_block_size_in_words_p)

         ,.wh_flit_width_p(dma_noc_flit_width_p)
         ,.wh_cid_width_p(dma_noc_cid_width_p)
         ,.wh_len_width_p(dma_noc_len_width_p)
         ,.wh_cord_width_p(dma_noc_cord_width_p)
         )
       dma2wh
        (.clk_i(clk_i)
         ,.reset_i(reset_r)

         ,.dma_pkt_i(dma_pkt_lo[i])
         ,.dma_pkt_v_i(dma_pkt_v_lo[i])
         ,.dma_pkt_yumi_o(dma_pkt_yumi_li[i])

         ,.dma_data_o(dma_data_li[i])
         ,.dma_data_v_o(dma_data_v_li[i])
         ,.dma_data_ready_and_i(dma_data_ready_and_lo[i])

         ,.dma_data_i(dma_data_lo[i])
         ,.dma_data_v_i(dma_data_v_lo[i])
         ,.dma_data_yumi_o(dma_data_yumi_li[i])

         ,.wh_link_sif_i(dma_link_li[i])
         ,.wh_link_sif_o(dma_link_lo[i])

         ,.my_wh_cord_i(cord_li)
         ,.my_wh_cid_i(cid_li)
         // TODO: Parameterizable?
         ,.dest_wh_cord_i('1)
         ,.dest_wh_cid_i('0)
         );
    end

  bsg_wormhole_concentrator
   #(.flit_width_p(dma_noc_flit_width_p)
     ,.len_width_p(dma_noc_len_width_p)
     ,.cid_width_p(dma_noc_cid_width_p)
     ,.cord_width_p(dma_noc_cord_width_p)
     ,.num_in_p(l2_dmas_p)
     ,.hold_on_valid_p(1)
     )
   dma_concentrate
    (.clk_i(clk_i)
     ,.reset_i(reset_r)

     ,.links_i(dma_link_lo)
     ,.links_o(dma_link_li)

     ,.concentrated_link_o(dma_link_o)
     ,.concentrated_link_i(dma_link_i)
     );

endmodule

