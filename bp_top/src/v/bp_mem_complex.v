
module bp_mem_complex
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                          core_clk_i
   , input                                                        core_reset_i

   , input                                                        coh_clk_i
   , input                                                        coh_reset_i

   , input                                                        mem_clk_i
   , input                                                        mem_reset_i

   , input  [coh_noc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_req_link_i
   , output [coh_noc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_req_link_o

   , input  [coh_noc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_cmd_link_i
   , output [coh_noc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_cmd_link_o

   , input  [coh_noc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_resp_link_i
   , output [coh_noc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_resp_link_o

   , input  [mem_noc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_cmd_link_i
   , output [mem_noc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_cmd_link_o

   , input  [mem_noc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_resp_link_i
   , output [mem_noc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_resp_link_o

   // TEMP
   , output [mem_noc_x_dim_p-1:0] [cce_mem_msg_width_lp-1:0]      dram_cmd_o
   , output [mem_noc_x_dim_p-1:0]                                 dram_cmd_v_o
   , input  [mem_noc_x_dim_p-1:0]                                 dram_cmd_yumi_i

   , input  [mem_noc_x_dim_p-1:0][cce_mem_msg_width_lp-1:0]       dram_resp_i
   , input  [mem_noc_x_dim_p-1:0]                                 dram_resp_v_i
   , output [mem_noc_x_dim_p-1:0]                                 dram_resp_ready_o
   );

  // Stub coherence links unless we have l2e
  assign coh_req_link_o  = '0;
  assign coh_cmd_link_o  = '0;
  assign coh_resp_link_o = '0;

  for (genvar i = 0; i < mem_noc_x_dim_p; i++)
    begin : links
      bp_me_cce_to_wormhole_link_client
       #(.bp_params_p(bp_params_p))
       dram_link
        (.clk_i(mem_clk_i)
         ,.reset_i(mem_reset_i)

         ,.mem_cmd_o(dram_cmd_o[i])
         ,.mem_cmd_v_o(dram_cmd_v_o[i])
         ,.mem_cmd_yumi_i(dram_cmd_yumi_i[i])

         ,.mem_resp_i(dram_resp_i[i])
         ,.mem_resp_v_i(dram_resp_v_i[i])
         ,.mem_resp_ready_o(dram_resp_ready_o[i])

         ,.cmd_link_i(mem_cmd_link_i[i])
         ,.cmd_link_o(mem_cmd_link_o[i])

         ,.resp_link_i(mem_resp_link_i[i])
         ,.resp_link_o(mem_resp_link_o[i])
         );
    end

endmodule

