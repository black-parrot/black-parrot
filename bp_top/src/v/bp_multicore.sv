/**
 *
 * bp_multicore.v
 *
 */

`include "bsg_noc_links.svh"

`include "bp_common_defines.svh"
`include "bp_top_defines.svh"

module bp_multicore
 import bp_common_pkg::*;
 import bp_be_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam dma_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(dma_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                               core_clk_i
   , input                                                             rt_clk_i
   , input                                                             core_reset_i

   , input                                                             coh_clk_i
   , input                                                             coh_reset_i

   , input                                                             mem_clk_i
   , input                                                             mem_reset_i

   , input                                                             dma_clk_i
   , input                                                             dma_reset_i

   , input [mem_noc_did_width_p-1:0]                                   my_did_i
   , input [mem_noc_did_width_p-1:0]                                   host_did_i

   , input [E:W][mem_noc_ral_link_width_lp-1:0]                        mem_fwd_link_i
   , output logic [E:W][mem_noc_ral_link_width_lp-1:0]                 mem_fwd_link_o

   , input [E:W][mem_noc_ral_link_width_lp-1:0]                        mem_rev_link_i
   , output logic [E:W][mem_noc_ral_link_width_lp-1:0]                 mem_rev_link_o

   , output logic [S:N][mc_x_dim_p-1:0][dma_noc_ral_link_width_lp-1:0] dma_link_o
   , input [S:N][mc_x_dim_p-1:0][dma_noc_ral_link_width_lp-1:0]        dma_link_i
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, hio_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, did_width_p);
  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(dma_noc_flit_width_p, bp_dma_ready_and_link_s);

  bp_coh_ready_and_link_s [E:W][cc_y_dim_p-1:0] coh_req_hor_link_li, coh_req_hor_link_lo;
  bp_coh_ready_and_link_s [E:W][cc_y_dim_p-1:0] coh_cmd_hor_link_li, coh_cmd_hor_link_lo;
  bp_coh_ready_and_link_s [E:W][cc_y_dim_p-1:0] coh_fill_hor_link_li, coh_fill_hor_link_lo;
  bp_coh_ready_and_link_s [E:W][cc_y_dim_p-1:0] coh_resp_hor_link_li, coh_resp_hor_link_lo;

  bp_coh_ready_and_link_s [S:N][cc_x_dim_p-1:0] coh_req_ver_link_li, coh_req_ver_link_lo;
  bp_coh_ready_and_link_s [S:N][cc_x_dim_p-1:0] coh_cmd_ver_link_li, coh_cmd_ver_link_lo;
  bp_coh_ready_and_link_s [S:N][cc_x_dim_p-1:0] coh_fill_ver_link_li, coh_fill_ver_link_lo;
  bp_coh_ready_and_link_s [S:N][cc_x_dim_p-1:0] coh_resp_ver_link_li, coh_resp_ver_link_lo;

  bp_dma_ready_and_link_s [S:N][cc_x_dim_p-1:0] dma_link_li, dma_link_lo;

  // IO and SACC complexes only use Req/Cmd networks
  assign coh_resp_ver_link_li[N] = '0;
  assign coh_resp_hor_link_li[W] = '0;
  assign coh_fill_ver_link_li[N] = '0;
  assign coh_fill_hor_link_li[W] = '0;
  // Memory complex does not use Fill network
  assign coh_fill_ver_link_li[S] = '0;

  assign dma_link_li[N] = '0;
  bp_core_complex
   #(.bp_params_p(bp_params_p))
   cc
    (.core_clk_i(core_clk_i)
     ,.rt_clk_i(rt_clk_i)
     ,.core_reset_i(core_reset_i)

     ,.coh_clk_i(coh_clk_i)
     ,.coh_reset_i(coh_reset_i)

     ,.dma_clk_i(dma_clk_i)
     ,.dma_reset_i(dma_reset_i)

     ,.my_did_i(my_did_i)
     ,.host_did_i(host_did_i)

     ,.coh_req_hor_link_i(coh_req_hor_link_li)
     ,.coh_req_hor_link_o(coh_req_hor_link_lo)

     ,.coh_cmd_hor_link_i(coh_cmd_hor_link_li)
     ,.coh_cmd_hor_link_o(coh_cmd_hor_link_lo)

     ,.coh_fill_hor_link_i(coh_fill_hor_link_li)
     ,.coh_fill_hor_link_o(coh_fill_hor_link_lo)

     ,.coh_resp_hor_link_i(coh_resp_hor_link_li)
     ,.coh_resp_hor_link_o(coh_resp_hor_link_lo)

     ,.coh_req_ver_link_i(coh_req_ver_link_li)
     ,.coh_req_ver_link_o(coh_req_ver_link_lo)

     ,.coh_cmd_ver_link_i(coh_cmd_ver_link_li)
     ,.coh_cmd_ver_link_o(coh_cmd_ver_link_lo)

     ,.coh_fill_ver_link_i(coh_fill_ver_link_li)
     ,.coh_fill_ver_link_o(coh_fill_ver_link_lo)

     ,.coh_resp_ver_link_i(coh_resp_ver_link_li)
     ,.coh_resp_ver_link_o(coh_resp_ver_link_lo)

     ,.dma_link_i(dma_link_li)
     ,.dma_link_o(dma_link_lo)
     );

  bp_io_complex
   #(.bp_params_p(bp_params_p))
   ic
    (.core_clk_i(core_clk_i)
     ,.core_reset_i(core_reset_i)

     ,.coh_clk_i(coh_clk_i)
     ,.coh_reset_i(coh_reset_i)

     ,.mem_clk_i(mem_clk_i)
     ,.mem_reset_i(mem_reset_i)

     ,.my_did_i(my_did_i)
     ,.host_did_i(host_did_i)

     ,.coh_req_link_i(coh_req_ver_link_lo[N])
     ,.coh_req_link_o(coh_req_ver_link_li[N])

     ,.coh_cmd_link_i(coh_cmd_ver_link_lo[N])
     ,.coh_cmd_link_o(coh_cmd_ver_link_li[N])

     ,.mem_fwd_link_i(mem_fwd_link_i)
     ,.mem_fwd_link_o(mem_fwd_link_o)

     ,.mem_rev_link_i(mem_rev_link_i)
     ,.mem_rev_link_o(mem_rev_link_o)
     );

  bp_dma_ready_and_link_s [S:N][cc_x_dim_p-1:0] l2e_dma_link_li, l2e_dma_link_lo;
  bp_mem_complex
   #(.bp_params_p(bp_params_p))
   mc
    (.core_clk_i(core_clk_i)
     ,.core_reset_i(core_reset_i)

     ,.coh_clk_i(coh_clk_i)
     ,.coh_reset_i(coh_reset_i)

     ,.dma_clk_i(dma_clk_i)
     ,.dma_reset_i(dma_reset_i)

     ,.my_did_i(my_did_i)

     ,.coh_req_link_i(coh_req_ver_link_lo[S])
     ,.coh_req_link_o(coh_req_ver_link_li[S])

     ,.coh_cmd_link_i(coh_cmd_ver_link_lo[S])
     ,.coh_cmd_link_o(coh_cmd_ver_link_li[S])

     ,.coh_resp_link_i(coh_resp_ver_link_lo[S])
     ,.coh_resp_link_o(coh_resp_ver_link_li[S])

     ,.dma_link_i(l2e_dma_link_li)
     ,.dma_link_o(l2e_dma_link_lo)
     );
  assign l2e_dma_link_li[N] = dma_link_lo[S];
  assign dma_link_li[S] = l2e_dma_link_lo[N];

  assign l2e_dma_link_li[S] = dma_link_i[S];
  assign dma_link_o[S] = l2e_dma_link_lo[S];

  bp_cacc_complex
   #(.bp_params_p(bp_params_p))
   cac
    (.core_clk_i(core_clk_i)
     ,.core_reset_i(core_reset_i)

     ,.coh_clk_i(coh_clk_i)
     ,.coh_reset_i(coh_reset_i)

     ,.coh_req_link_i(coh_req_hor_link_lo[E])
     ,.coh_req_link_o(coh_req_hor_link_li[E])

     ,.coh_cmd_link_i(coh_cmd_hor_link_lo[E])
     ,.coh_cmd_link_o(coh_cmd_hor_link_li[E])

     ,.coh_fill_link_i(coh_fill_hor_link_lo[E])
     ,.coh_fill_link_o(coh_fill_hor_link_li[E])

     ,.coh_resp_link_i(coh_resp_hor_link_lo[E])
     ,.coh_resp_link_o(coh_resp_hor_link_li[E])
     );

  bp_sacc_complex
   #(.bp_params_p(bp_params_p))
   sac
    (.core_clk_i(core_clk_i)
     ,.core_reset_i(core_reset_i)

     ,.coh_clk_i(coh_clk_i)
     ,.coh_reset_i(coh_reset_i)

     ,.coh_req_link_i(coh_req_hor_link_lo[W])
     ,.coh_req_link_o(coh_req_hor_link_li[W])

     ,.coh_cmd_link_i(coh_cmd_hor_link_lo[W])
     ,.coh_cmd_link_o(coh_cmd_hor_link_li[W])
     );

endmodule

