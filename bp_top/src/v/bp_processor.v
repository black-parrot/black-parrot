/**
 *
 * bp_processor.v
 *
 */
 
`include "bsg_noc_links.vh"

module bp_processor
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                            core_clk_i
   , input                                          core_reset_i

   , input                                          coh_clk_i
   , input                                          coh_reset_i

   , input                                          mem_clk_i
   , input                                          mem_reset_i

   , input [mem_noc_did_width_p-1:0]                my_did_i

   , input  [E:W][mem_noc_ral_link_width_lp-1:0]    io_cmd_link_i
   , output [E:W][mem_noc_ral_link_width_lp-1:0]    io_cmd_link_o

   , input  [E:W][mem_noc_ral_link_width_lp-1:0]    io_resp_link_i
   , output [E:W][mem_noc_ral_link_width_lp-1:0]    io_resp_link_o

   // TEMP
   , output [cc_x_dim_p-1:0][cce_mem_msg_width_lp-1:0] dram_cmd_o
   , output [cc_x_dim_p-1:0]                           dram_cmd_v_o
   , input  [cc_x_dim_p-1:0]                           dram_cmd_yumi_i

   , input  [cc_x_dim_p-1:0][cce_mem_msg_width_lp-1:0] dram_resp_i
   , input  [cc_x_dim_p-1:0]                           dram_resp_v_i
   , output [cc_x_dim_p-1:0]                           dram_resp_ready_o
   );

`declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
`declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
`declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
`declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
`declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);

bp_coh_ready_and_link_s [S:N][cc_x_dim_p-1:0] coh_req_link_li, coh_req_link_lo;
bp_coh_ready_and_link_s [S:N][cc_x_dim_p-1:0] coh_cmd_link_li, coh_cmd_link_lo;
bp_coh_ready_and_link_s [S:N][cc_x_dim_p-1:0] coh_resp_link_li, coh_resp_link_lo;

bp_mem_ready_and_link_s [cc_x_dim_p-1:0] mem_cmd_link_li, mem_cmd_link_lo;
bp_mem_ready_and_link_s [cc_x_dim_p-1:0] mem_resp_link_li, mem_resp_link_lo;

assign coh_resp_link_lo[N] = '0;
bp_core_complex
 #(.bp_params_p(bp_params_p))
 cc
  (.core_clk_i(core_clk_i)
   ,.core_reset_i(core_reset_i)

   ,.coh_clk_i(coh_clk_i)
   ,.coh_reset_i(coh_reset_i)

   ,.mem_clk_i(mem_clk_i)
   ,.mem_reset_i(mem_reset_i)

   ,.my_did_i(my_did_i)

   ,.coh_req_link_i(coh_req_link_lo)
   ,.coh_req_link_o(coh_req_link_li)

   ,.coh_resp_link_i(coh_resp_link_lo)
   ,.coh_resp_link_o(coh_resp_link_li)

   ,.coh_cmd_link_i(coh_cmd_link_lo)
   ,.coh_cmd_link_o(coh_cmd_link_li)

   ,.mem_cmd_link_i(mem_cmd_link_li)
   ,.mem_cmd_link_o(mem_cmd_link_lo)

   ,.mem_resp_link_i(mem_resp_link_li)
   ,.mem_resp_link_o(mem_resp_link_lo)
   );

bp_io_complex
 #(.bp_params_p(bp_params_p))
 ioc
  (.core_clk_i(core_clk_i)
   ,.core_reset_i(core_reset_i)

   ,.coh_clk_i(coh_clk_i)
   ,.coh_reset_i(coh_reset_i)

   ,.mem_clk_i(mem_clk_i)
   ,.mem_reset_i(mem_reset_i)

   ,.my_did_i(my_did_i)

   ,.coh_req_link_i(coh_req_link_li[N])
   ,.coh_req_link_o(coh_req_link_lo[N])

   ,.coh_cmd_link_i(coh_cmd_link_li[N])
   ,.coh_cmd_link_o(coh_cmd_link_lo[N])

   ,.io_cmd_link_i(io_cmd_link_i)
   ,.io_cmd_link_o(io_cmd_link_o)

   ,.io_resp_link_i(io_resp_link_i)
   ,.io_resp_link_o(io_resp_link_o)
   );

bp_mem_complex
 #(.bp_params_p(bp_params_p))
 mc
  (.core_clk_i(core_clk_i)
   ,.core_reset_i(core_reset_i)

   ,.coh_clk_i(coh_clk_i)
   ,.coh_reset_i(coh_reset_i)

   ,.mem_clk_i(mem_clk_i)
   ,.mem_reset_i(mem_reset_i)

   ,.coh_req_link_i(coh_req_link_li[S])
   ,.coh_req_link_o(coh_req_link_lo[S])

   ,.coh_cmd_link_i(coh_cmd_link_li[S])
   ,.coh_cmd_link_o(coh_cmd_link_lo[S])

   ,.coh_resp_link_i(coh_resp_link_li[S])
   ,.coh_resp_link_o(coh_resp_link_lo[S])

   ,.mem_cmd_link_i(mem_cmd_link_lo)
   ,.mem_cmd_link_o(mem_cmd_link_li)

   ,.mem_resp_link_i(mem_resp_link_lo)
   ,.mem_resp_link_o(mem_resp_link_li)

   ,.dram_cmd_o(dram_cmd_o)
   ,.dram_cmd_v_o(dram_cmd_v_o)
   ,.dram_cmd_yumi_i(dram_cmd_yumi_i)

   ,.dram_resp_i(dram_resp_i)
   ,.dram_resp_v_i(dram_resp_v_i)
   ,.dram_resp_ready_o(dram_resp_ready_o)
   );

endmodule

