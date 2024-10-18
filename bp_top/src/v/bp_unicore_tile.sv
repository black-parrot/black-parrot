/**
 *
 * bp_unicore_tile.v
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"
`include "bp_top_defines.svh"
`include "bsg_cache.svh"
`include "bsg_noc_links.svh"

module bp_unicore_tile
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

   // Wormhole parameters
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   , localparam dma_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(dma_noc_flit_width_p)
   )
  (input                                                         clk_i
   , input                                                       rt_clk_i
   , input                                                       reset_i

   // Memory side connection
   , input [mem_noc_did_width_p-1:0]                             my_did_i
   , input [mem_noc_did_width_p-1:0]                             host_did_i
   , input [coh_noc_cord_width_p-1:0]                            my_cord_i

   , input [mem_noc_ral_link_width_lp-1:0]                       mem_fwd_link_i
   , output logic [mem_noc_ral_link_width_lp-1:0]                mem_fwd_link_o

   , input [mem_noc_ral_link_width_lp-1:0]                       mem_rev_link_i
   , output logic [mem_noc_ral_link_width_lp-1:0]                mem_rev_link_o

   , output logic [l2_dmas_p-1:0][dma_noc_ral_link_width_lp-1:0] dma_link_o
   , input [l2_dmas_p-1:0][dma_noc_ral_link_width_lp-1:0]        dma_link_i
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(dma_noc_flit_width_p, bp_dma_ready_and_link_s);

  // Reset
  logic reset_r;
  always_ff @(posedge clk_i)
    reset_r <= reset_i;

  // Network links
  `bp_cast_i(bp_mem_ready_and_link_s, mem_fwd_link);
  `bp_cast_o(bp_mem_ready_and_link_s, mem_fwd_link);
  `bp_cast_i(bp_mem_ready_and_link_s, mem_rev_link);
  `bp_cast_o(bp_mem_ready_and_link_s, mem_rev_link);
  `bp_cast_i(bp_dma_ready_and_link_s [l2_dmas_p-1:0], dma_link);
  `bp_cast_o(bp_dma_ready_and_link_s [l2_dmas_p-1:0], dma_link);

  // Core-side LCE-CCE network connections
  bp_bedrock_mem_fwd_header_s mem_fwd_header_lo;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_lo;
  logic mem_fwd_v_lo, mem_fwd_ready_and_li;
  logic [mem_noc_cord_width_p-1:0] mem_fwd_dst_cord_lo;
  logic [mem_noc_cid_width_p-1:0] mem_fwd_dst_cid_lo;

  bp_bedrock_mem_rev_header_s mem_rev_header_li;
  logic [bedrock_fill_width_p-1:0] mem_rev_data_li;
  logic mem_rev_v_li, mem_rev_ready_and_lo;
  logic [mem_noc_cord_width_p-1:0] mem_rev_dst_cord_li;
  logic [mem_noc_cid_width_p-1:0] mem_rev_dst_cid_li;

  bp_bedrock_mem_fwd_header_s mem_fwd_header_li;
  logic [bedrock_fill_width_p-1:0] mem_fwd_data_li;
  logic mem_fwd_v_li, mem_fwd_ready_and_lo;
  logic [mem_noc_cord_width_p-1:0] mem_fwd_dst_cord_li;
  logic [mem_noc_cid_width_p-1:0] mem_fwd_dst_cid_li;

  bp_bedrock_mem_rev_header_s mem_rev_header_lo;
  logic [bedrock_fill_width_p-1:0] mem_rev_data_lo;
  logic mem_rev_v_lo, mem_rev_ready_and_li;
  logic [mem_noc_cord_width_p-1:0] mem_rev_dst_cord_lo;
  logic [mem_noc_cid_width_p-1:0] mem_rev_dst_cid_lo;

  `declare_bsg_cache_dma_pkt_s(daddr_width_p, l2_block_size_in_words_p);
  bsg_cache_dma_pkt_s [l2_dmas_p-1:0] dma_pkt_lo;
  logic [l2_dmas_p-1:0] dma_pkt_v_lo, dma_pkt_yumi_li;
  logic [l2_dmas_p-1:0][l2_fill_width_p-1:0] dma_data_li;
  logic [l2_dmas_p-1:0] dma_data_v_li, dma_data_ready_and_lo;
  logic [l2_dmas_p-1:0][l2_fill_width_p-1:0] dma_data_lo;
  logic [l2_dmas_p-1:0] dma_data_v_lo, dma_data_yumi_li;

  // TODO: Programmable?
  assign mem_fwd_dst_cord_lo = '1;
  assign mem_fwd_dst_cid_lo = '0;
  bp_me_stream_to_wormhole
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(mem_noc_flit_width_p)
     ,.cord_width_p(mem_noc_cord_width_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.cid_width_p(mem_noc_cid_width_p)
     ,.pr_hdr_width_p(mem_fwd_header_width_lp)
     ,.pr_payload_width_p(mem_fwd_payload_width_lp)
     ,.pr_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   mem_fwd_stream_to_wh
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.pr_hdr_i(mem_fwd_header_lo)
    ,.pr_data_i(mem_fwd_data_lo)
    ,.pr_v_i(mem_fwd_v_lo)
    ,.pr_ready_and_o(mem_fwd_ready_and_li)
    ,.dst_cord_i(mem_fwd_dst_cord_lo)
    ,.dst_cid_i(mem_fwd_dst_cid_lo)

    ,.link_data_o(mem_fwd_link_cast_o.data)
    ,.link_v_o(mem_fwd_link_cast_o.v)
    ,.link_ready_and_i(mem_fwd_link_cast_i.ready_and_rev)
    );

  bp_me_wormhole_to_stream
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(mem_noc_flit_width_p)
     ,.cord_width_p(mem_noc_cord_width_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.cid_width_p(mem_noc_cid_width_p)
     ,.pr_hdr_width_p(mem_rev_header_width_lp)
     ,.pr_payload_width_p(mem_rev_payload_width_lp)
     ,.pr_stream_mask_p(mem_rev_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   mem_rev_wh_to_stream
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_data_i(mem_rev_link_cast_i.data)
    ,.link_v_i(mem_rev_link_cast_i.v)
    ,.link_ready_and_o(mem_rev_link_cast_o.ready_and_rev)

    ,.pr_hdr_o(mem_rev_header_li)
    ,.pr_data_o(mem_rev_data_li)
    ,.pr_v_o(mem_rev_v_li)
    ,.pr_ready_and_i(mem_rev_ready_and_lo)
    );

  bp_me_wormhole_to_stream
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(mem_noc_flit_width_p)
     ,.cord_width_p(mem_noc_cord_width_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.cid_width_p(mem_noc_cid_width_p)
     ,.pr_hdr_width_p(mem_fwd_header_width_lp)
     ,.pr_payload_width_p(mem_fwd_payload_width_lp)
     ,.pr_stream_mask_p(mem_fwd_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   mem_fwd_wh_to_stream
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.link_data_i(mem_fwd_link_cast_i.data)
    ,.link_v_i(mem_fwd_link_cast_i.v)
    ,.link_ready_and_o(mem_fwd_link_cast_o.ready_and_rev)

    ,.pr_hdr_o(mem_fwd_header_li)
    ,.pr_data_o(mem_fwd_data_li)
    ,.pr_v_o(mem_fwd_v_li)
    ,.pr_ready_and_i(mem_fwd_ready_and_lo)
    );

  // TODO: Programmable?
  assign mem_rev_dst_cord_lo = '1;
  assign mem_rev_dst_cid_lo = '0;
  bp_me_stream_to_wormhole
   #(.bp_params_p(bp_params_p)
     ,.flit_width_p(mem_noc_flit_width_p)
     ,.cord_width_p(mem_noc_cord_width_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.cid_width_p(mem_noc_cid_width_p)
     ,.pr_hdr_width_p(mem_rev_header_width_lp)
     ,.pr_payload_width_p(mem_rev_payload_width_lp)
     ,.pr_stream_mask_p(mem_rev_stream_mask_gp)
     ,.pr_data_width_p(bedrock_fill_width_p)
     )
   mem_rev_stream_to_wh
   (.clk_i(clk_i)
    ,.reset_i(reset_r)

    ,.pr_hdr_i(mem_rev_header_lo)
    ,.pr_data_i(mem_rev_data_lo)
    ,.pr_v_i(mem_rev_v_lo)
    ,.pr_ready_and_o(mem_rev_ready_and_li)
    ,.dst_cord_i(mem_rev_dst_cord_lo)
    ,.dst_cid_i(mem_rev_dst_cid_lo)

    ,.link_data_o(mem_rev_link_cast_o.data)
    ,.link_v_o(mem_rev_link_cast_o.v)
    ,.link_ready_and_i(mem_rev_link_cast_i.ready_and_rev)
    );

  for (genvar i = 0; i < l2_dmas_p; i++)
    begin : dma
      // TODO: Parameterizable?
      wire [dma_noc_cord_width_p-1:0] cord_li = '0;
      wire [dma_noc_cid_width_p-1:0] cid_li = i;
      wire [dma_noc_cord_width_p-1:0] dst_cord_li = '1;
      wire [dma_noc_cid_width_p-1:0] dst_cid_li = i;

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

         ,.wh_link_sif_i(dma_link_cast_i[i])
         ,.wh_link_sif_o(dma_link_cast_o[i])

         ,.my_wh_cord_i(cord_li)
         ,.my_wh_cid_i(cid_li)
         ,.dest_wh_cord_i(dst_cord_li)
         ,.dest_wh_cid_i(dst_cid_li)
         );
    end

  bp_unicore
   #(.bp_params_p(bp_params_p))
   unicore
    (.clk_i(clk_i)
     ,.rt_clk_i(rt_clk_i)
     ,.reset_i(reset_i)

     ,.my_did_i(my_did_li)
     ,.host_did_i(host_did_li)
     ,.my_cord_i(cord_li)

     ,.mem_fwd_header_o(mem_fwd_header_lo)
     ,.mem_fwd_data_o(mem_fwd_data_lo)
     ,.mem_fwd_v_o(mem_fwd_v_lo)
     ,.mem_fwd_ready_and_i(mem_fwd_ready_and_li)

     ,.mem_rev_header_i(mem_rev_header_li)
     ,.mem_rev_data_i(mem_rev_data_li)
     ,.mem_rev_v_i(mem_rev_v_li)
     ,.mem_rev_ready_and_o(mem_rev_ready_and_lo)

     ,.mem_fwd_header_i(mem_fwd_header_li)
     ,.mem_fwd_data_i(mem_fwd_data_li)
     ,.mem_fwd_v_i(mem_fwd_v_li)
     ,.mem_fwd_ready_and_o(mem_fwd_ready_and_lo)

     ,.mem_rev_header_o(mem_rev_header_lo)
     ,.mem_rev_data_o(mem_rev_data_lo)
     ,.mem_rev_v_o(mem_rev_v_lo)
     ,.mem_rev_ready_and_i(mem_rev_ready_and_li)

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

endmodule

