
module bp_mem_complex
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                     core_clk_i
   , input                                                   core_reset_i

   , input                                                   coh_clk_i
   , input                                                   coh_reset_i

   , input                                                   mem_clk_i
   , input                                                   mem_reset_i

   , input  [mc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_req_link_i
   , output [mc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_req_link_o

   , input  [mc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_cmd_link_i
   , output [mc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_cmd_link_o

   , input  [mc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_cmd_link_i
   , output [mc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_resp_link_o

   , output [mem_noc_ral_link_width_lp-1:0]                  dram_cmd_link_o
   , input [mem_noc_ral_link_width_lp-1:0]                   dram_resp_link_i
   );

  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);

  // Right now this is passthrough, but should be replaced by l2e tiles
  wire unused = &{coh_req_link_i, coh_cmd_link_i};
  assign coh_req_link_o  = '0;
  assign coh_cmd_link_o  = '0;

  bsg_wormhole_concentrator
   #(.flit_width_p(mem_noc_flit_width_p)
     ,.len_width_p(mem_noc_len_width_p)
     ,.cid_width_p(mem_noc_cid_width_p)
     ,.cord_width_p(mem_noc_cord_width_p)
     ,.num_in_p(mc_x_dim_p)
     )
   concentrator
    (.clk_i(mem_clk_i)
     ,.reset_i(mem_reset_i)

     ,.links_i(mem_cmd_link_i)
     ,.links_o(mem_resp_link_o)

     ,.concentrated_link_o(dram_cmd_link_o)
     ,.concentrated_link_i(dram_resp_link_i)
     );

endmodule

