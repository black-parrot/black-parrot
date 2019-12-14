
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

   , input  [mc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_resp_link_i
   , output [mc_x_dim_p-1:0][coh_noc_ral_link_width_lp-1:0]  coh_resp_link_o

   , input  [mc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_cmd_link_i
   , output [mc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_cmd_link_o

   , input  [mc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_resp_link_i
   , output [mc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_resp_link_o

   // TEMP
   , output [mc_x_dim_p-1:0] [cce_mem_msg_width_lp-1:0]      dram_cmd_o
   , output [mc_x_dim_p-1:0]                                 dram_cmd_v_o
   , input  [mc_x_dim_p-1:0]                                 dram_cmd_yumi_i

   , input  [mc_x_dim_p-1:0][cce_mem_msg_width_lp-1:0]       dram_resp_i
   , input  [mc_x_dim_p-1:0]                                 dram_resp_v_i
   , output [mc_x_dim_p-1:0]                                 dram_resp_ready_o
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bp_io_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);

  bp_mem_ready_and_link_s [mc_x_dim_p-1:0][S:N] mem_cmd_link_li, mem_cmd_link_lo;
  bp_mem_ready_and_link_s [mc_x_dim_p-1:0][S:N] mem_resp_link_li, mem_resp_link_lo;

  if (mc_y_dim_p > 0)
    begin : mc_stitch
      // Right now this is passthrough, but should be replaced by l2e tiles
      assign coh_req_link_o  = '0;
      assign coh_cmd_link_o  = '0;
      assign coh_resp_link_o = '0;

      for (genvar i = 0; i < mc_x_dim_p; i++)
        begin : stub
          assign mem_cmd_link_lo[S]  = mem_cmd_link_i;
          assign mem_resp_link_lo[S] = mem_resp_link_i;

          assign mem_cmd_link_o      = mem_cmd_link_li[S];
          assign mem_resp_link_o     = mem_resp_link_li[S];
        end
    end
  else
    begin : stub
      // Stub coherence links
      assign coh_req_link_o  = '0;
      assign coh_cmd_link_o  = '0;
      assign coh_resp_link_o = '0;

      for (genvar i = 0; i < mc_x_dim_p; i++)
        begin : stub
          assign mem_cmd_link_lo[i][S]  = mem_cmd_link_i[i];
          assign mem_resp_link_lo[i][S] = mem_resp_link_i[i];

          assign mem_cmd_link_o[i]      = mem_cmd_link_li[i][S];
          assign mem_resp_link_o[i]     = mem_resp_link_li[i][S];
        end
    end

  for (genvar i = 0; i < mc_x_dim_p; i++)
    begin : links
      bp_me_cce_to_mem_link_client
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

         ,.cmd_link_i(mem_cmd_link_lo[i][S])
         ,.cmd_link_o(mem_cmd_link_li[i][S])

         ,.resp_link_i(mem_resp_link_lo[i][S])
         ,.resp_link_o(mem_resp_link_li[i][S])
         );
    end

endmodule

