/**
 *
 * wrapper.sv
 *
 */

`include "bsg_noc_links.vh"

module wrapper
 import bsg_wormhole_router_pkg::*;
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 #(parameter bp_params_e bp_params_p = BP_CFG_FLOWVAR
   `declare_bp_proc_params(bp_params_p)

   , localparam uce_mem_data_width_lp = `BSG_MAX(icache_fill_width_p, dcache_fill_width_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, uce_mem_data_width_lp, lce_id_width_p, lce_assoc_p, uce)

   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(caddr_width_p)
   )
  (input                                                    clk_i
   , input                                                  reset_i

   // Outgoing I/O
   , output [cce_mem_msg_width_lp-1:0]                      io_cmd_o
   , output                                                 io_cmd_v_o
   , input                                                  io_cmd_ready_i

   , input [cce_mem_msg_width_lp-1:0]                       io_resp_i
   , input                                                  io_resp_v_i
   , output                                                 io_resp_yumi_o

   // Incoming I/O
   , input [cce_mem_msg_width_lp-1:0]                       io_cmd_i
   , input                                                  io_cmd_v_i
   , output                                                 io_cmd_yumi_o

   , output [cce_mem_msg_width_lp-1:0]                      io_resp_o
   , output                                                 io_resp_v_o
   , input                                                  io_resp_ready_i

   // DRAM interface
   , output logic [num_cce_p-1:0][dma_pkt_width_lp-1:0]     dma_pkt_o
   , output logic [num_cce_p-1:0]                           dma_pkt_v_o
   , input [num_cce_p-1:0]                                  dma_pkt_yumi_i

   , input [num_cce_p-1:0][l2_fill_width_p-1:0]             dma_data_i
   , input [num_cce_p-1:0]                                  dma_data_v_i
   , output logic [num_cce_p-1:0]                           dma_data_ready_and_o

   , output logic [num_cce_p-1:0][l2_fill_width_p-1:0]      dma_data_o
   , output logic [num_cce_p-1:0]                           dma_data_v_o
   , input [num_cce_p-1:0]                                  dma_data_yumi_i
   );

  if (multicore_p)
    begin : multicore
      `declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bp_io_noc_ral_link_s);
      `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_noc_ral_link_s);

      bp_io_noc_ral_link_s proc_cmd_link_li, proc_cmd_link_lo;
      bp_io_noc_ral_link_s proc_resp_link_li, proc_resp_link_lo;
      bp_mem_noc_ral_link_s [mc_x_dim_p-1:0] dram_cmd_link_lo, dram_resp_link_li;
      bp_io_noc_ral_link_s stub_cmd_link_li, stub_resp_link_li;
      bp_io_noc_ral_link_s stub_cmd_link_lo, stub_resp_link_lo;

      wire [io_noc_did_width_p-1:0] proc_did_li = 1;
      wire [io_noc_did_width_p-1:0] dram_did_li = '1;

      assign stub_cmd_link_li  = '0;
      assign stub_resp_link_li = '0;

      bp_multicore
       #(.bp_params_p(bp_params_p))
       dut
        (.core_clk_i(clk_i)
         ,.core_reset_i(reset_i)

         ,.coh_clk_i(clk_i)
         ,.coh_reset_i(reset_i)

         ,.io_clk_i(clk_i)
         ,.io_reset_i(reset_i)

         ,.mem_clk_i(clk_i)
         ,.mem_reset_i(reset_i)

         ,.my_did_i(proc_did_li)
         ,.host_did_i(dram_did_li)

         ,.io_cmd_link_i({proc_cmd_link_li, stub_cmd_link_li})
         ,.io_cmd_link_o({proc_cmd_link_lo, stub_cmd_link_lo})

         ,.io_resp_link_i({proc_resp_link_li, stub_resp_link_li})
         ,.io_resp_link_o({proc_resp_link_lo, stub_resp_link_lo})

         ,.dram_cmd_link_o(dram_cmd_link_lo)
         ,.dram_resp_link_i(dram_resp_link_li)
         );

      logic io_cmd_ready_lo, io_resp_ready_lo;
      assign io_cmd_yumi_o = io_cmd_ready_lo & io_cmd_v_i;
      assign io_resp_yumi_o = io_resp_ready_lo & io_resp_v_i;
      wire [io_noc_cord_width_p-1:0] dst_cord_lo = 1;
      bp_me_cce_to_mem_link_bidir
       #(.bp_params_p(bp_params_p)
         ,.num_outstanding_req_p(io_noc_max_credits_p)
         ,.flit_width_p(io_noc_flit_width_p)
         ,.cord_width_p(io_noc_cord_width_p)
         ,.cid_width_p(io_noc_cid_width_p)
         ,.len_width_p(io_noc_len_width_p)
         )
       host_link
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.mem_cmd_i(io_cmd_i)
         ,.mem_cmd_v_i(io_cmd_v_i)
         ,.mem_cmd_ready_o(io_cmd_ready_lo)

         ,.mem_resp_o(io_resp_o)
         ,.mem_resp_v_o(io_resp_v_o)
         ,.mem_resp_yumi_i(io_resp_ready_i & io_resp_v_o)

         ,.my_cord_i(io_noc_cord_width_p'(dram_did_li))
         ,.my_cid_i('0)
         ,.dst_cord_i(dst_cord_lo)
         ,.dst_cid_i('0)

         ,.mem_cmd_o(io_cmd_o)
         ,.mem_cmd_v_o(io_cmd_v_o)
         ,.mem_cmd_yumi_i(io_cmd_ready_i & io_cmd_v_o)

         ,.mem_resp_i(io_resp_i)
         ,.mem_resp_v_i(io_resp_v_i)
         ,.mem_resp_ready_o(io_resp_ready_lo)

         ,.cmd_link_i(proc_cmd_link_lo)
         ,.cmd_link_o(proc_cmd_link_li)
         ,.resp_link_i(proc_resp_link_lo)
         ,.resp_link_o(proc_resp_link_li)
         );

      `declare_bsg_cache_wh_header_flit_s(mem_noc_flit_width_p, mem_noc_cord_width_p, mem_noc_len_width_p, mem_noc_cid_width_p);
      localparam cce_per_col_lp = num_cce_p/mc_x_dim_p;
      for (genvar i = 0; i < mc_x_dim_p; i++)
        begin : column
          bsg_cache_wh_header_flit_s header_flit;
          assign header_flit = dram_cmd_link_lo[i];
          wire [`BSG_SAFE_CLOG2(cce_per_col_lp)-1:0] dma_id_li = header_flit.src_cord-1'b1;
          bsg_wormhole_to_cache_dma_fanout
           #(.wh_flit_width_p(mem_noc_flit_width_p)
             ,.wh_cid_width_p(mem_noc_cid_width_p)
             ,.wh_len_width_p(mem_noc_len_width_p)
             ,.wh_cord_width_p(mem_noc_cord_width_p)

             ,.num_dma_p(cce_per_col_lp)
             ,.dma_addr_width_p(caddr_width_p)
             ,.dma_burst_len_p(l2_block_size_in_fill_p)
             )
           wh_to_cache_dma
            (.clk_i(clk_i)
             ,.reset_i(reset_i)

             ,.wh_link_sif_i(dram_cmd_link_lo[i])
             ,.wh_dma_id_i(dma_id_li)
             ,.wh_link_sif_o(dram_resp_link_li[i])

             ,.dma_pkt_o(dma_pkt_o[i*cce_per_col_lp+:cce_per_col_lp])
             ,.dma_pkt_v_o(dma_pkt_v_o[i*cce_per_col_lp+:cce_per_col_lp])
             ,.dma_pkt_yumi_i(dma_pkt_yumi_i[i*cce_per_col_lp+:cce_per_col_lp])

             ,.dma_data_i(dma_data_i[i*cce_per_col_lp+:cce_per_col_lp])
             ,.dma_data_v_i(dma_data_v_i[i*cce_per_col_lp+:cce_per_col_lp])
             ,.dma_data_ready_and_o(dma_data_ready_and_o[i*cce_per_col_lp+:cce_per_col_lp])

             ,.dma_data_o(dma_data_o[i*cce_per_col_lp+:cce_per_col_lp])
             ,.dma_data_v_o(dma_data_v_o[i*cce_per_col_lp+:cce_per_col_lp])
             ,.dma_data_yumi_i(dma_data_yumi_i[i*cce_per_col_lp+:cce_per_col_lp])
             );
        end
    end
  else
    begin : unicore
      `declare_bp_bedrock_mem_if(paddr_width_p, uce_mem_data_width_lp, lce_id_width_p, lce_assoc_p,
uce);
      bp_bedrock_uce_mem_msg_s io_cmd_lo, io_cmd_li;
      bp_bedrock_uce_mem_msg_s io_resp_lo, io_resp_li;
      bp_unicore
       #(.bp_params_p(bp_params_p))
       dut
        (.io_cmd_o(io_cmd_lo)
         ,.io_cmd_i(io_cmd_li)
         ,.io_resp_o(io_resp_lo)
         ,.io_resp_i(io_resp_li)
         ,.*
         );

      assign io_cmd_o = io_cmd_lo;
      assign io_cmd_li = io_cmd_i;
      assign io_resp_o = io_resp_lo;
      assign io_resp_li = io_resp_i;
    end

endmodule

