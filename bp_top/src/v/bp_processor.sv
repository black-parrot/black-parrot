/**
 *
 * bp_processor.sv
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"
`include "bsg_noc_links.svh"

module bp_processor
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)

   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(daddr_width_p, l2_block_size_in_words_p)
   )
  (input                                                                clk_i
   , input                                                              rt_clk_i
   , input                                                              reset_i

   , input [did_width_p-1:0]                                            my_did_i
   , input [did_width_p-1:0]                                            host_did_i

   // Outgoing I/O
   , output logic [mem_fwd_header_width_lp-1:0]                         mem_fwd_header_o
   , output logic [bedrock_fill_width_p-1:0]                            mem_fwd_data_o
   , output logic                                                       mem_fwd_v_o
   , input                                                              mem_fwd_ready_and_i

   , input [mem_rev_header_width_lp-1:0]                                mem_rev_header_i
   , input [bedrock_fill_width_p-1:0]                                   mem_rev_data_i
   , input                                                              mem_rev_v_i
   , output logic                                                       mem_rev_ready_and_o

   // Incoming I/O
   , input [mem_fwd_header_width_lp-1:0]                                mem_fwd_header_i
   , input [bedrock_fill_width_p-1:0]                                   mem_fwd_data_i
   , input                                                              mem_fwd_v_i
   , output logic                                                       mem_fwd_ready_and_o

   , output logic [mem_rev_header_width_lp-1:0]                         mem_rev_header_o
   , output logic [bedrock_fill_width_p-1:0]                            mem_rev_data_o
   , output logic                                                       mem_rev_v_o
   , input                                                              mem_rev_ready_and_i

   // DRAM interface
   , output logic [num_cce_p-1:0][l2_dmas_p-1:0][dma_pkt_width_lp-1:0]  dma_pkt_o
   , output logic [num_cce_p-1:0][l2_dmas_p-1:0]                        dma_pkt_v_o
   , input [num_cce_p-1:0][l2_dmas_p-1:0]                               dma_pkt_ready_and_i

   , input [num_cce_p-1:0][l2_dmas_p-1:0][l2_fill_width_p-1:0]          dma_data_i
   , input [num_cce_p-1:0][l2_dmas_p-1:0]                               dma_data_v_i
   , output logic [num_cce_p-1:0][l2_dmas_p-1:0]                        dma_data_ready_and_o

   , output logic [num_cce_p-1:0][l2_dmas_p-1:0][l2_fill_width_p-1:0]   dma_data_o
   , output logic [num_cce_p-1:0][l2_dmas_p-1:0]                        dma_data_v_o
   , input [num_cce_p-1:0][l2_dmas_p-1:0]                               dma_data_ready_and_i
   );

  if (cce_type_p != e_cce_uce)
    begin : m

      `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_noc_ral_link_s);
      `declare_bsg_ready_and_link_sif_s(dma_noc_flit_width_p, bp_dma_noc_ral_link_s);

      bp_mem_noc_ral_link_s [E:W] proc_fwd_link_li, proc_fwd_link_lo;
      bp_mem_noc_ral_link_s [E:W] proc_rev_link_li, proc_rev_link_lo;
      bp_dma_noc_ral_link_s [S:N][mc_x_dim_p-1:0] dma_link_lo, dma_link_li;

      assign dma_link_li[N] = '0;
      assign proc_fwd_link_li[W] = '0;
      assign proc_rev_link_li[W] = '0;

      bp_multicore
       #(.bp_params_p(bp_params_p))
       multicore
        (.core_clk_i(clk_i)
         ,.rt_clk_i(rt_clk_i)
         ,.core_reset_i(reset_i)

         ,.coh_clk_i(clk_i)
         ,.coh_reset_i(reset_i)

         ,.mem_clk_i(clk_i)
         ,.mem_reset_i(reset_i)

         ,.dma_clk_i(clk_i)
         ,.dma_reset_i(reset_i)

         ,.my_did_i(my_did_i)
         ,.host_did_i(host_did_i)

         ,.mem_fwd_link_i(proc_fwd_link_li)
         ,.mem_fwd_link_o(proc_fwd_link_lo)

         ,.mem_rev_link_i(proc_rev_link_li)
         ,.mem_rev_link_o(proc_rev_link_lo)

         ,.dma_link_i(dma_link_li)
         ,.dma_link_o(dma_link_lo)
         );

      `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);
      `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bsg_ready_and_link_sif_s);
      `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
      `bp_cast_o(bp_bedrock_mem_rev_header_s, mem_rev_header);
      `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
      `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);

      wire [mem_noc_cord_width_p-1:0] mem_fwd_dst_cord_li = my_did_i;
      wire [mem_noc_cid_width_p-1:0] mem_fwd_dst_cid_li = '0;

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
       mem_fwd_stream_to_wormhole
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.pr_hdr_i(mem_fwd_header_cast_i)
         ,.pr_data_i(mem_fwd_data_i)
         ,.pr_v_i(mem_fwd_v_i)
         ,.pr_ready_and_o(mem_fwd_ready_and_o)
         ,.dst_cord_i(mem_fwd_dst_cord_li)
         ,.dst_cid_i(mem_fwd_dst_cid_li)

         ,.link_data_o(proc_fwd_link_li[E].data)
         ,.link_v_o(proc_fwd_link_li[E].v)
         ,.link_ready_and_i(proc_fwd_link_lo[E].ready_and_rev)
         );

      wire [mem_noc_cord_width_p-1:0] mem_rev_dst_cord_li = mem_rev_header_cast_i.payload.src_did;
      wire [mem_noc_cid_width_p-1:0] mem_rev_dst_cid_li = '0;

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
       mem_rev_stream_to_wormhole
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.pr_hdr_i(mem_rev_header_cast_i)
         ,.pr_data_i(mem_rev_data_i)
         ,.pr_v_i(mem_rev_v_i)
         ,.pr_ready_and_o(mem_rev_ready_and_o)
         ,.dst_cord_i(mem_rev_dst_cord_li)
         ,.dst_cid_i(mem_rev_dst_cid_li)

         ,.link_data_o(proc_rev_link_li[E].data)
         ,.link_v_o(proc_rev_link_li[E].v)
         ,.link_ready_and_i(proc_rev_link_lo[E].ready_and_rev)
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
       mem_fwd_wormhole_to_stream
       (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.link_data_i(proc_fwd_link_lo[E].data)
        ,.link_v_i(proc_fwd_link_lo[E].v)
        ,.link_ready_and_o(proc_fwd_link_li[E].ready_and_rev)

        ,.pr_hdr_o(mem_fwd_header_cast_o)
        ,.pr_data_o(mem_fwd_data_o)
        ,.pr_v_o(mem_fwd_v_o)
        ,.pr_ready_and_i(mem_fwd_ready_and_i)
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
       mem_rev_wormhole_to_stream
       (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.link_data_i(proc_rev_link_lo[E].data)
        ,.link_v_i(proc_rev_link_lo[E].v)
        ,.link_ready_and_o(proc_rev_link_li[E].ready_and_rev)

        ,.pr_hdr_o(mem_rev_header_cast_o)
        ,.pr_data_o(mem_rev_data_o)
        ,.pr_v_o(mem_rev_v_o)
        ,.pr_ready_and_i(mem_rev_ready_and_i)
        );

      import bsg_cache_pkg::*;
      `declare_bsg_cache_wh_header_flit_s(dma_noc_flit_width_p, dma_noc_cord_width_p, dma_noc_len_width_p, dma_noc_cid_width_p);
      localparam dma_per_col_lp = num_cce_p/mc_x_dim_p*l2_dmas_p;
      logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0][dma_pkt_width_lp-1:0] dma_pkt_lo;
      logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0] dma_pkt_v_lo, dma_pkt_yumi_li;
      logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0][l2_fill_width_p-1:0] dma_data_lo;
      logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0] dma_data_v_lo, dma_data_yumi_li;
      logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0][l2_fill_width_p-1:0] dma_data_li;
      logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0] dma_data_v_li, dma_data_ready_and_lo;
      for (genvar i = 0; i < mc_x_dim_p; i++)
        begin : column
          bsg_cache_wh_header_flit_s header_flit;
          assign header_flit = dma_link_lo[S][i].data;
          wire [`BSG_SAFE_CLOG2(dma_per_col_lp)-1:0] dma_id_li =
            l2_dmas_p*(header_flit.src_cord-1)+header_flit.src_cid;
          bsg_wormhole_to_cache_dma_fanout
           #(.wh_flit_width_p(dma_noc_flit_width_p)
             ,.wh_cid_width_p(dma_noc_cid_width_p)
             ,.wh_len_width_p(dma_noc_len_width_p)
             ,.wh_cord_width_p(dma_noc_cord_width_p)

             ,.num_dma_p(dma_per_col_lp)
             ,.dma_addr_width_p(daddr_width_p)
             ,.dma_burst_len_p(l2_block_size_in_fill_p)
             ,.dma_mask_width_p(l2_block_size_in_words_p)
             )
           wh_to_cache_dma
            (.clk_i(clk_i)
             ,.reset_i(reset_i)

             ,.wh_link_sif_i(dma_link_lo[S][i])
             ,.wh_dma_id_i(dma_id_li)
             ,.wh_link_sif_o(dma_link_li[S][i])

             ,.dma_pkt_o(dma_pkt_lo[i])
             ,.dma_pkt_v_o(dma_pkt_v_lo[i])
             ,.dma_pkt_yumi_i(dma_pkt_yumi_li[i])

             ,.dma_data_i(dma_data_li[i])
             ,.dma_data_v_i(dma_data_v_li[i])
             ,.dma_data_ready_and_o(dma_data_ready_and_lo[i])

             ,.dma_data_o(dma_data_lo[i])
             ,.dma_data_v_o(dma_data_v_lo[i])
             ,.dma_data_yumi_i(dma_data_yumi_li[i])
             );
        end

      // Transpose the DMA IDs
      for (genvar i = 0; i < num_cce_p; i++)
        begin : rof1
          for (genvar j = 0; j < l2_dmas_p; j++)
            begin : rof2
              localparam col_lp     = i%mc_x_dim_p;
              localparam col_pos_lp = (i/mc_x_dim_p)*l2_dmas_p+j;

              assign dma_pkt_o[i][j] = dma_pkt_lo[col_lp][col_pos_lp];
              assign dma_pkt_v_o[i][j] = dma_pkt_v_lo[col_lp][col_pos_lp];
              assign dma_pkt_yumi_li[col_lp][col_pos_lp] = dma_pkt_ready_and_i[i][j] & dma_pkt_v_o[i][j];

              assign dma_data_o[i][j] = dma_data_lo[col_lp][col_pos_lp];
              assign dma_data_v_o[i][j] = dma_data_v_lo[col_lp][col_pos_lp];
              assign dma_data_yumi_li[col_lp][col_pos_lp] = dma_data_ready_and_i[i][j] & dma_data_v_o[i][j];

              assign dma_data_li[col_lp][col_pos_lp] = dma_data_i[i][j];
              assign dma_data_v_li[col_lp][col_pos_lp] = dma_data_v_i[i][j];
              assign dma_data_ready_and_o[i][j] = dma_data_ready_and_lo[col_lp][col_pos_lp];
            end
        end
    end
  else
    begin : u
      bp_unicore
       #(.bp_params_p(bp_params_p))
       unicore
        (.my_cord_i('0), .*);
    end

endmodule

