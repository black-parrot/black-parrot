/**
 *
 * wrapper.sv
 *
 */

`include "bp_common_defines.svh"
`include "bp_be_defines.svh"
`include "bp_me_defines.svh"
`include "bsg_noc_links.vh"

module wrapper
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)

   , parameter io_data_width_p = (cce_type_p == e_cce_uce) ? uce_fill_width_p : bedrock_data_width_p
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(daddr_width_p)
   )
  (input                                                                clk_i
   , input                                                              rt_clk_i
   , input                                                              reset_i

   , input [did_width_p-1:0]                                            my_did_i
   , input [did_width_p-1:0]                                            host_did_i

   // Outgoing I/O
   , output logic [mem_fwd_header_width_lp-1:0]                         mem_fwd_header_o
   , output logic [io_data_width_p-1:0]                                 mem_fwd_data_o
   , output logic                                                       mem_fwd_v_o
   , input                                                              mem_fwd_ready_and_i
   , output logic                                                       mem_fwd_last_o

   , input [mem_rev_header_width_lp-1:0]                                mem_rev_header_i
   , input [io_data_width_p-1:0]                                        mem_rev_data_i
   , input                                                              mem_rev_v_i
   , output logic                                                       mem_rev_ready_and_o
   , input                                                              mem_rev_last_i

   // Incoming I/O
   , input [mem_fwd_header_width_lp-1:0]                                mem_fwd_header_i
   , input [io_data_width_p-1:0]                                        mem_fwd_data_i
   , input                                                              mem_fwd_v_i
   , output logic                                                       mem_fwd_ready_and_o
   , input                                                              mem_fwd_last_i

   , output logic [mem_rev_header_width_lp-1:0]                         mem_rev_header_o
   , output logic [io_data_width_p-1:0]                                 mem_rev_data_o
   , output logic                                                       mem_rev_v_o
   , input                                                              mem_rev_ready_and_i
   , output logic                                                       mem_rev_last_o

   // DRAM interface
   , output logic [num_cce_p-1:0][l2_banks_p-1:0][dma_pkt_width_lp-1:0] dma_pkt_o
   , output logic [num_cce_p-1:0][l2_banks_p-1:0]                       dma_pkt_v_o
   , input [num_cce_p-1:0][l2_banks_p-1:0]                              dma_pkt_ready_and_i

   , input [num_cce_p-1:0][l2_banks_p-1:0][l2_fill_width_p-1:0]         dma_data_i
   , input [num_cce_p-1:0][l2_banks_p-1:0]                              dma_data_v_i
   , output logic [num_cce_p-1:0][l2_banks_p-1:0]                       dma_data_ready_and_o

   , output logic [num_cce_p-1:0][l2_banks_p-1:0][l2_fill_width_p-1:0]  dma_data_o
   , output logic [num_cce_p-1:0][l2_banks_p-1:0]                       dma_data_v_o
   , input [num_cce_p-1:0][l2_banks_p-1:0]                              dma_data_ready_and_i
   );

  if (cce_type_p != e_cce_uce)
    begin : multicore

      `declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bp_io_noc_ral_link_s);
      `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_noc_ral_link_s);

      bp_io_noc_ral_link_s proc_fwd_link_li, proc_fwd_link_lo;
      bp_io_noc_ral_link_s proc_rev_link_li, proc_rev_link_lo;
      bp_mem_noc_ral_link_s [mc_x_dim_p-1:0] mem_dma_link_lo, mem_dma_link_li;
      bp_io_noc_ral_link_s stub_fwd_link_li, stub_rev_link_li;
      bp_io_noc_ral_link_s stub_fwd_link_lo, stub_rev_link_lo;

      assign stub_fwd_link_li  = '0;
      assign stub_rev_link_li = '0;

      bp_multicore
       #(.bp_params_p(bp_params_p))
       dut
        (.core_clk_i(clk_i)
         ,.rt_clk_i(rt_clk_i)
         ,.core_reset_i(reset_i)

         ,.coh_clk_i(clk_i)
         ,.coh_reset_i(reset_i)

         ,.io_clk_i(clk_i)
         ,.io_reset_i(reset_i)

         ,.mem_clk_i(clk_i)
         ,.mem_reset_i(reset_i)

         ,.my_did_i(my_did_i)
         ,.host_did_i(host_did_i)

         ,.io_fwd_link_i({proc_fwd_link_li, stub_fwd_link_li})
         ,.io_fwd_link_o({proc_fwd_link_lo, stub_fwd_link_lo})

         ,.io_rev_link_i({proc_rev_link_li, stub_rev_link_li})
         ,.io_rev_link_o({proc_rev_link_lo, stub_rev_link_lo})

         ,.mem_dma_link_o(mem_dma_link_lo)
         ,.mem_dma_link_i(mem_dma_link_li)
         );

      `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
      `declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bsg_ready_and_link_sif_s);
      `bp_cast_i(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
      `bp_cast_o(bp_bedrock_mem_rev_header_s, mem_rev_header);
      `bp_cast_o(bp_bedrock_mem_fwd_header_s, mem_fwd_header);
      `bp_cast_i(bp_bedrock_mem_rev_header_s, mem_rev_header);

      bp_bedrock_mem_fwd_header_s mem_fwd_header_li;
      logic [io_data_width_p-1:0] mem_fwd_data_li;
      logic mem_fwd_header_v_li, mem_fwd_has_data_li, mem_fwd_header_ready_and_lo;
      logic mem_fwd_data_v_li, mem_fwd_last_li, mem_fwd_data_ready_and_lo;

      bp_bedrock_mem_rev_header_s mem_rev_header_lo;
      logic [io_data_width_p-1:0] mem_rev_data_lo;
      logic mem_rev_header_v_lo, mem_rev_has_data_lo, mem_rev_header_ready_and_li;
      logic mem_rev_data_v_lo, mem_rev_last_lo, mem_rev_data_ready_and_li;

      bp_me_stream_to_burst
       #(.bp_params_p(bp_params_p)
         ,.data_width_p(io_data_width_p)
         ,.payload_width_p(mem_fwd_payload_width_lp)
         ,.payload_mask_p(mem_fwd_payload_mask_gp)
         )
       mem_fwd_s2b
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.in_msg_header_i(mem_fwd_header_cast_i)
         ,.in_msg_data_i(mem_fwd_data_i)
         ,.in_msg_v_i(mem_fwd_v_i)
         ,.in_msg_ready_and_o(mem_fwd_ready_and_o)
         ,.in_msg_last_i(mem_fwd_last_i)

         ,.out_msg_header_o(mem_fwd_header_li)
         ,.out_msg_header_v_o(mem_fwd_header_v_li)
         ,.out_msg_header_ready_and_i(mem_fwd_header_ready_and_lo)
         ,.out_msg_has_data_o(mem_fwd_has_data_li)
         ,.out_msg_data_o(mem_fwd_data_li)
         ,.out_msg_data_v_o(mem_fwd_data_v_li)
         ,.out_msg_data_ready_and_i(mem_fwd_data_ready_and_lo)
         ,.out_msg_last_o(mem_fwd_last_li)
         );

      bp_me_burst_to_stream
       #(.bp_params_p(bp_params_p)
         ,.data_width_p(io_data_width_p)
         ,.payload_width_p(mem_rev_payload_width_lp)
         ,.block_width_p(cce_block_width_p)
         ,.payload_mask_p(mem_rev_payload_mask_gp)
         )
       mem_rev_b2s
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.in_msg_header_i(mem_rev_header_lo)
         ,.in_msg_header_v_i(mem_rev_header_v_lo)
         ,.in_msg_header_ready_and_o(mem_rev_header_ready_and_li)
         ,.in_msg_has_data_i(mem_rev_has_data_lo)
         ,.in_msg_data_i(mem_rev_data_lo)
         ,.in_msg_data_v_i(mem_rev_data_v_lo)
         ,.in_msg_data_ready_and_o(mem_rev_data_ready_and_li)
         ,.in_msg_last_i(mem_rev_last_lo)

         ,.out_msg_header_o(mem_rev_header_cast_o)
         ,.out_msg_data_o(mem_rev_data_o)
         ,.out_msg_v_o(mem_rev_v_o)
         ,.out_msg_ready_and_i(mem_rev_ready_and_i)
         ,.out_msg_last_o(mem_rev_last_o)
         );

      bp_bedrock_mem_fwd_header_s mem_fwd_header_lo;
      logic [io_data_width_p-1:0] mem_fwd_data_lo;
      logic mem_fwd_header_v_lo, mem_fwd_has_data_lo, mem_fwd_header_ready_and_li;
      logic mem_fwd_data_v_lo, mem_fwd_last_lo, mem_fwd_data_ready_and_li;

      bp_bedrock_mem_rev_header_s mem_rev_header_li;
      logic [io_data_width_p-1:0] mem_rev_data_li;
      logic mem_rev_header_v_li, mem_rev_has_data_li, mem_rev_header_ready_and_lo;
      logic mem_rev_data_v_li, mem_rev_last_li, mem_rev_data_ready_and_lo;

      bp_me_stream_to_burst
       #(.bp_params_p(bp_params_p)
         ,.data_width_p(io_data_width_p)
         ,.payload_width_p(mem_rev_payload_width_lp)
         ,.payload_mask_p(mem_rev_payload_mask_gp)
         )
       mem_rev_s2b
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.in_msg_header_i(mem_rev_header_cast_i)
         ,.in_msg_data_i(mem_rev_data_i)
         ,.in_msg_v_i(mem_rev_v_i)
         ,.in_msg_ready_and_o(mem_rev_ready_and_o)
         ,.in_msg_last_i(mem_rev_last_i)

         ,.out_msg_header_o(mem_rev_header_li)
         ,.out_msg_header_v_o(mem_rev_header_v_li)
         ,.out_msg_header_ready_and_i(mem_rev_header_ready_and_lo)
         ,.out_msg_has_data_o(mem_rev_has_data_li)
         ,.out_msg_data_o(mem_rev_data_li)
         ,.out_msg_data_v_o(mem_rev_data_v_li)
         ,.out_msg_data_ready_and_i(mem_rev_data_ready_and_lo)
         ,.out_msg_last_o(mem_rev_last_li)
         );

      bp_me_burst_to_stream
       #(.bp_params_p(bp_params_p)
         ,.data_width_p(io_data_width_p)
         ,.payload_width_p(mem_fwd_payload_width_lp)
         ,.block_width_p(cce_block_width_p)
         ,.payload_mask_p(mem_fwd_payload_mask_gp)
         )
       mem_fwd_b2s
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.in_msg_header_i(mem_fwd_header_lo)
         ,.in_msg_header_v_i(mem_fwd_header_v_lo)
         ,.in_msg_header_ready_and_o(mem_fwd_header_ready_and_li)
         ,.in_msg_has_data_i(mem_fwd_has_data_lo)
         ,.in_msg_data_i(mem_fwd_data_lo)
         ,.in_msg_data_v_i(mem_fwd_data_v_lo)
         ,.in_msg_data_ready_and_o(mem_fwd_data_ready_and_li)
         ,.in_msg_last_i(mem_fwd_last_lo)

         ,.out_msg_header_o(mem_fwd_header_cast_o)
         ,.out_msg_data_o(mem_fwd_data_o)
         ,.out_msg_v_o(mem_fwd_v_o)
         ,.out_msg_ready_and_i(mem_fwd_ready_and_i)
         ,.out_msg_last_o(mem_fwd_last_o)
         );

      wire [io_noc_cord_width_p-1:0] mem_fwd_dst_cord_li = 1;
      wire [io_noc_cid_width_p-1:0] mem_fwd_dst_cid_li = '0;

      bp_me_burst_to_wormhole
       #(.bp_params_p(bp_params_p)
         ,.flit_width_p(io_noc_flit_width_p)
         ,.cord_width_p(io_noc_cord_width_p)
         ,.len_width_p(io_noc_len_width_p)
         ,.cid_width_p(io_noc_cid_width_p)
         ,.pr_hdr_width_p(mem_fwd_header_width_lp)
         ,.pr_payload_width_p(mem_fwd_payload_width_lp)
         ,.pr_payload_mask_p(mem_fwd_payload_mask_gp)
         ,.pr_data_width_p(bedrock_data_width_p)
         )
       mem_fwd_burst_to_wormhole
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.pr_hdr_i(mem_fwd_header_li)
         ,.pr_hdr_v_i(mem_fwd_header_v_li)
         ,.pr_hdr_ready_and_o(mem_fwd_header_ready_and_lo)
         ,.pr_has_data_i(mem_fwd_has_data_li)
         ,.dst_cord_i(mem_fwd_dst_cord_li)
         ,.dst_cid_i(mem_fwd_dst_cid_li)

         ,.pr_data_i(mem_fwd_data_li)
         ,.pr_data_v_i(mem_fwd_data_v_li)
         ,.pr_data_ready_and_o(mem_fwd_data_ready_and_lo)
         ,.pr_last_i(mem_fwd_last_li)

         ,.link_data_o(proc_fwd_link_li.data)
         ,.link_v_o(proc_fwd_link_li.v)
         ,.link_ready_and_i(proc_fwd_link_lo.ready_and_rev)
         );

      wire [io_noc_cord_width_p-1:0] mem_rev_dst_cord_li = mem_rev_header_cast_i.payload.did;
      wire [io_noc_cid_width_p-1:0] mem_rev_dst_cid_li = '0;

      bp_me_burst_to_wormhole
       #(.bp_params_p(bp_params_p)
         ,.flit_width_p(io_noc_flit_width_p)
         ,.cord_width_p(io_noc_cord_width_p)
         ,.len_width_p(io_noc_len_width_p)
         ,.cid_width_p(io_noc_cid_width_p)
         ,.pr_hdr_width_p(mem_rev_header_width_lp)
         ,.pr_payload_width_p(mem_rev_payload_width_lp)
         ,.pr_payload_mask_p(mem_rev_payload_mask_gp)
         ,.pr_data_width_p(bedrock_data_width_p)
         )
       mem_rev_burst_to_wormhole
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.pr_hdr_i(mem_rev_header_li)
         ,.pr_hdr_v_i(mem_rev_header_v_li)
         ,.pr_hdr_ready_and_o(mem_rev_header_ready_and_lo)
         ,.pr_has_data_i(mem_rev_has_data_li)
         ,.dst_cord_i(mem_rev_dst_cord_li)
         ,.dst_cid_i(mem_rev_dst_cid_li)

         ,.pr_data_i(mem_rev_data_li)
         ,.pr_data_v_i(mem_rev_data_v_li)
         ,.pr_data_ready_and_o(mem_rev_data_ready_and_lo)
         ,.pr_last_i(mem_rev_last_li)

         ,.link_data_o(proc_rev_link_li.data)
         ,.link_v_o(proc_rev_link_li.v)
         ,.link_ready_and_i(proc_rev_link_lo.ready_and_rev)
         );

      bp_me_wormhole_to_burst
       #(.bp_params_p(bp_params_p)
         ,.flit_width_p(io_noc_flit_width_p)
         ,.cord_width_p(io_noc_cord_width_p)
         ,.len_width_p(io_noc_len_width_p)
         ,.cid_width_p(io_noc_cid_width_p)
         ,.pr_hdr_width_p(mem_fwd_header_width_lp)
         ,.pr_payload_width_p(mem_fwd_payload_width_lp)
         ,.pr_data_width_p(bedrock_data_width_p)
         )
       mem_fwd_wormhole_to_burst
       (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.link_data_i(proc_fwd_link_lo.data)
        ,.link_v_i(proc_fwd_link_lo.v)
        ,.link_ready_and_o(proc_fwd_link_li.ready_and_rev)

        ,.pr_hdr_o(mem_fwd_header_lo)
        ,.pr_hdr_v_o(mem_fwd_header_v_lo)
        ,.pr_hdr_ready_and_i(mem_fwd_header_ready_and_li)
        ,.pr_has_data_o(mem_fwd_has_data_lo)

        ,.pr_data_o(mem_fwd_data_lo)
        ,.pr_data_v_o(mem_fwd_data_v_lo)
        ,.pr_data_ready_and_i(mem_fwd_data_ready_and_li)
        ,.pr_last_o(mem_fwd_last_lo)
        );

      bp_me_wormhole_to_burst
       #(.bp_params_p(bp_params_p)
         ,.flit_width_p(io_noc_flit_width_p)
         ,.cord_width_p(io_noc_cord_width_p)
         ,.len_width_p(io_noc_len_width_p)
         ,.cid_width_p(io_noc_cid_width_p)
         ,.pr_hdr_width_p(mem_rev_header_width_lp)
         ,.pr_payload_width_p(mem_rev_payload_width_lp)
         ,.pr_data_width_p(bedrock_data_width_p)
         )
       mem_rev_wormhole_to_burst
       (.clk_i(clk_i)
        ,.reset_i(reset_i)

        ,.link_data_i(proc_rev_link_lo.data)
        ,.link_v_i(proc_rev_link_lo.v)
        ,.link_ready_and_o(proc_rev_link_li.ready_and_rev)

        ,.pr_hdr_o(mem_rev_header_lo)
        ,.pr_hdr_v_o(mem_rev_header_v_lo)
        ,.pr_hdr_ready_and_i(mem_rev_header_ready_and_li)
        ,.pr_has_data_o(mem_rev_has_data_lo)

        ,.pr_data_o(mem_rev_data_lo)
        ,.pr_data_v_o(mem_rev_data_v_lo)
        ,.pr_data_ready_and_i(mem_rev_data_ready_and_li)
        ,.pr_last_o(mem_rev_last_lo)
        );

      `declare_bsg_cache_wh_header_flit_s(mem_noc_flit_width_p, mem_noc_cord_width_p, mem_noc_len_width_p, mem_noc_cid_width_p);
      localparam dma_per_col_lp = num_cce_p/mc_x_dim_p*l2_banks_p;
      logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0][dma_pkt_width_lp-1:0] dma_pkt_lo;
      logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0] dma_pkt_v_lo, dma_pkt_yumi_li;
      logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0][l2_fill_width_p-1:0] dma_data_lo;
      logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0] dma_data_v_lo, dma_data_yumi_li;
      logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0][l2_fill_width_p-1:0] dma_data_li;
      logic [mc_x_dim_p-1:0][dma_per_col_lp-1:0] dma_data_v_li, dma_data_ready_and_lo;
      for (genvar i = 0; i < mc_x_dim_p; i++)
        begin : column
          bsg_cache_wh_header_flit_s header_flit;
          assign header_flit = mem_dma_link_lo[i].data;
          wire [`BSG_SAFE_CLOG2(dma_per_col_lp)-1:0] dma_id_li =
            l2_banks_p*(header_flit.src_cord-1)+header_flit.src_cid;
          bsg_wormhole_to_cache_dma_fanout
           #(.wh_flit_width_p(mem_noc_flit_width_p)
             ,.wh_cid_width_p(mem_noc_cid_width_p)
             ,.wh_len_width_p(mem_noc_len_width_p)
             ,.wh_cord_width_p(mem_noc_cord_width_p)

             ,.num_dma_p(dma_per_col_lp)
             ,.dma_addr_width_p(daddr_width_p)
             ,.dma_burst_len_p(l2_block_size_in_fill_p)
             )
           wh_to_cache_dma
            (.clk_i(clk_i)
             ,.reset_i(reset_i)

             ,.wh_link_sif_i(mem_dma_link_lo[i])
             ,.wh_dma_id_i(dma_id_li)
             ,.wh_link_sif_o(mem_dma_link_li[i])

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
          for (genvar j = 0; j < l2_banks_p; j++)
            begin : rof2
              localparam col_lp     = i%mc_x_dim_p;
              localparam col_pos_lp = (i/mc_x_dim_p)*l2_banks_p+j;

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
    begin : unicore
      bp_unicore
       #(.bp_params_p(bp_params_p))
       dut
        (.my_cord_i('0), .*);
    end

endmodule

