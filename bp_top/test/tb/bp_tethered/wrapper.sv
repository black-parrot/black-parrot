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

   , parameter io_data_width_p = multicore_p ? cce_block_width_p : uce_fill_width_p
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p)

   , localparam dma_pkt_width_lp = `bsg_cache_dma_pkt_width(daddr_width_p)
   )
  (input                                                    clk_i
   , input                                                  reset_i

   , input [did_width_p-1:0]                                my_did_i
   , input [did_width_p-1:0]                                host_did_i

   // Outgoing I/O
   , output logic [mem_header_width_lp-1:0]                 io_cmd_header_o
   , output logic [io_data_width_p-1:0]                     io_cmd_data_o
   , output logic                                           io_cmd_v_o
   , input                                                  io_cmd_ready_and_i
   , output logic                                           io_cmd_last_o

   , input [mem_header_width_lp-1:0]                        io_resp_header_i
   , input [io_data_width_p-1:0]                            io_resp_data_i
   , input                                                  io_resp_v_i
   , output logic                                           io_resp_ready_and_o
   , input                                                  io_resp_last_i

   // Incoming I/O
   , input [mem_header_width_lp-1:0]                        io_cmd_header_i
   , input [io_data_width_p-1:0]                            io_cmd_data_i
   , input                                                  io_cmd_v_i
   , output logic                                           io_cmd_ready_and_o
   , input                                                  io_cmd_last_i

   , output logic [mem_header_width_lp-1:0]                 io_resp_header_o
   , output logic [io_data_width_p-1:0]                     io_resp_data_o
   , output logic                                           io_resp_v_o
   , input                                                  io_resp_ready_and_i
   , output logic                                           io_resp_last_o

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

      if (io_data_width_p != cce_block_width_p)
        $fatal(0, "io_data_width_p must be same as cce_block_width_p in multicore");

      `declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bp_io_noc_ral_link_s);
      `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_noc_ral_link_s);

      bp_io_noc_ral_link_s proc_cmd_link_li, proc_cmd_link_lo;
      bp_io_noc_ral_link_s proc_resp_link_li, proc_resp_link_lo;
      bp_mem_noc_ral_link_s [mc_x_dim_p-1:0] dram_cmd_link_lo, dram_resp_link_li;
      bp_io_noc_ral_link_s stub_cmd_link_li, stub_resp_link_li;
      bp_io_noc_ral_link_s stub_cmd_link_lo, stub_resp_link_lo;

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

         ,.my_did_i(my_did_i)
         ,.host_did_i(host_did_i)

         ,.io_cmd_link_i({proc_cmd_link_li, stub_cmd_link_li})
         ,.io_cmd_link_o({proc_cmd_link_lo, stub_cmd_link_lo})

         ,.io_resp_link_i({proc_resp_link_li, stub_resp_link_li})
         ,.io_resp_link_o({proc_resp_link_lo, stub_resp_link_lo})

         ,.dram_cmd_link_o(dram_cmd_link_lo)
         ,.dram_resp_link_i(dram_resp_link_li)
         );

      wire [io_noc_cord_width_p-1:0] dst_cord_lo = 1;

      `declare_bp_bedrock_mem_if(paddr_width_p, did_width_p, lce_id_width_p, lce_assoc_p);
      `declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bsg_ready_and_link_sif_s);
      `bp_cast_i(bp_bedrock_mem_header_s, io_cmd_header);
      `bp_cast_o(bp_bedrock_mem_header_s, io_resp_header);
      `bp_cast_o(bp_bedrock_mem_header_s, io_cmd_header);
      `bp_cast_i(bp_bedrock_mem_header_s, io_resp_header);

      bsg_ready_and_link_sif_s send_cmd_link_lo, send_resp_link_li;
      bsg_ready_and_link_sif_s recv_cmd_link_li, recv_resp_link_lo;
      assign recv_cmd_link_li   = '{data          : proc_cmd_link_lo.data
                                    ,v            : proc_cmd_link_lo.v
                                    ,ready_and_rev: proc_resp_link_lo.ready_and_rev
                                    };
      assign proc_cmd_link_li   = '{data          : send_cmd_link_lo.data
                                    ,v            : send_cmd_link_lo.v
                                    ,ready_and_rev: recv_resp_link_lo.ready_and_rev
                                    };
    
      assign send_resp_link_li  = '{data          : proc_resp_link_lo.data
                                    ,v            : proc_resp_link_lo.v
                                    ,ready_and_rev: proc_cmd_link_lo.ready_and_rev
                                    };
      assign proc_resp_link_li  = '{data          : recv_resp_link_lo.data
                                    ,v            : recv_resp_link_lo.v
                                    ,ready_and_rev: send_cmd_link_lo.ready_and_rev
                                    };
 
      bp_me_cce_to_mem_link_send
       #(.bp_params_p(bp_params_p)
         ,.flit_width_p(io_noc_flit_width_p)
         ,.cord_width_p(io_noc_cord_width_p)
         ,.cid_width_p(io_noc_cid_width_p)
         ,.len_width_p(io_noc_len_width_p)
         )
       send_link
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.dst_cord_i(dst_cord_lo)
         ,.dst_cid_i('0)

         ,.mem_cmd_header_i(io_cmd_header_cast_i)
         ,.mem_cmd_data_i(io_cmd_data_i)
         ,.mem_cmd_v_i(io_cmd_v_i)
         ,.mem_cmd_ready_and_o(io_cmd_ready_and_o)
         ,.mem_cmd_last_i(io_cmd_last_i)

         ,.mem_resp_header_o(io_resp_header_cast_o)
         ,.mem_resp_data_o(io_resp_data_o)
         ,.mem_resp_v_o(io_resp_v_o)
         ,.mem_resp_yumi_i(io_resp_ready_and_i & io_resp_v_o)
         ,.mem_resp_last_o(io_resp_last_o)


         ,.cmd_link_o(send_cmd_link_lo)
         ,.resp_link_i(send_resp_link_li)
         );

      bp_me_cce_to_mem_link_recv
       #(.bp_params_p(bp_params_p)
         ,.flit_width_p(io_noc_flit_width_p)
         ,.cord_width_p(io_noc_cord_width_p)
         ,.cid_width_p(io_noc_cid_width_p)
         ,.len_width_p(io_noc_len_width_p)
         )
       recv_link
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.dst_cord_i(io_resp_header_cast_i.payload.did)
         ,.dst_cid_i('0)

         ,.mem_cmd_header_o(io_cmd_header_cast_o)
         ,.mem_cmd_data_o(io_cmd_data_o)
         ,.mem_cmd_v_o(io_cmd_v_o)
         ,.mem_cmd_yumi_i(io_cmd_ready_and_i & io_cmd_v_o)
         ,.mem_cmd_last_o(io_cmd_last_o)

         ,.mem_resp_header_i(io_resp_header_cast_i)
         ,.mem_resp_data_i(io_resp_data_i)
         ,.mem_resp_v_i(io_resp_v_i)
         ,.mem_resp_ready_and_o(io_resp_ready_and_o)
         ,.mem_resp_last_i(io_resp_last_i)

         ,.cmd_link_i(recv_cmd_link_li)
         ,.resp_link_o(recv_resp_link_lo)
         );   

      `declare_bsg_cache_wh_header_flit_s(mem_noc_flit_width_p, mem_noc_cord_width_p, mem_noc_len_width_p, mem_noc_cid_width_p);
      localparam cce_per_col_lp = num_cce_p/mc_x_dim_p;
      for (genvar i = 0; i < mc_x_dim_p; i++)
        begin : column
          bsg_cache_wh_header_flit_s header_flit;
          assign header_flit = dram_cmd_link_lo[i].data;
          wire [`BSG_SAFE_CLOG2(cce_per_col_lp)-1:0] dma_id_li = header_flit.src_cord-1'b1;
          bsg_wormhole_to_cache_dma_fanout
           #(.wh_flit_width_p(mem_noc_flit_width_p)
             ,.wh_cid_width_p(mem_noc_cid_width_p)
             ,.wh_len_width_p(mem_noc_len_width_p)
             ,.wh_cord_width_p(mem_noc_cord_width_p)

             ,.num_dma_p(cce_per_col_lp)
             ,.dma_addr_width_p(daddr_width_p)
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
      bp_unicore_complex
       #(.bp_params_p(bp_params_p))
       dut
        (.*);
    end

endmodule

