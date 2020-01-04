
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

   , input  [mc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_cmd_link_i
   , output [mc_x_dim_p-1:0][mem_noc_ral_link_width_lp-1:0]  mem_resp_link_o

   , output logic [E:W][mem_noc_ral_link_width_lp-1:0]       bypass_cmd_link_o
   , input logic [E:W][mem_noc_ral_link_width_lp-1:0]        bypass_resp_link_i

   // TODO: DMC links
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bp_io_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);

  bp_mem_ready_and_link_s [S:N][mc_x_dim_p-1:0] mem_cmd_link_li, mem_cmd_link_lo;
  bp_mem_ready_and_link_s [S:N][mc_x_dim_p-1:0] mem_resp_link_li, mem_resp_link_lo;

  // Right now this is passthrough, but should be replaced by l2e tiles
  assign coh_req_link_o  = '0;
  assign coh_cmd_link_o  = '0;

  assign mem_cmd_link_lo[S]  = mem_cmd_link_i;
  assign mem_resp_link_o     = mem_resp_link_li[S];

  bp_mem_ready_and_link_s cmd_concentrated_link_lo, resp_concentrated_link_li;
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

     ,.links_i(mem_cmd_link_lo[S])
     ,.links_o(mem_resp_link_li[S])

     ,.concentrated_link_o(cmd_concentrated_link_lo)
     ,.concentrated_link_i(resp_concentrated_link_li)
     );

  bp_mem_ready_and_link_s dram_cmd_link_li, dram_resp_link_lo;

  bp_cce_mem_msg_s dram_cmd_lo;
  logic dram_cmd_v_lo, dram_cmd_yumi_li;
  bp_cce_mem_msg_s dram_resp_li;
  logic dram_resp_v_li, dram_resp_ready_lo;

  bp_me_cce_to_mem_link_client
   #(.bp_params_p(bp_params_p))
   dram_link
    (.clk_i(mem_clk_i)
     ,.reset_i(mem_reset_i)

     ,.mem_cmd_o(dram_cmd_lo)
     ,.mem_cmd_v_o(dram_cmd_v_lo)
     ,.mem_cmd_yumi_i(dram_cmd_yumi_li)

     ,.mem_resp_i(dram_resp_li)
     ,.mem_resp_v_i(dram_resp_v_li)
     ,.mem_resp_ready_o(dram_resp_ready_lo)

     ,.cmd_link_i(dram_cmd_link_li)
     ,.resp_link_o(dram_resp_link_lo)
     );

  typedef enum bit [1:0]
  {
    e_dram_bypass_east  = 2'b00
    ,e_dram_bypass_west = 2'b01
    ,e_dram_enable      = 2'b11
  } dram_mode_e;

  dram_mode_e dram_mode_li;
  assign dram_mode_li = e_dram_bypass_east;

  assign dram_cmd_yumi_li = '0;
  assign dram_resp_li = '0;
  assign dram_resp_v_li = '0;

  always_comb
    begin
      dram_cmd_link_li = '0;
      bypass_cmd_link_o = '0;

      case (dram_mode_li)
        e_dram_enable:
          begin
            dram_cmd_link_li = cmd_concentrated_link_lo;
            resp_concentrated_link_li = dram_resp_link_lo;
          end
        e_dram_bypass_west:
          begin
            bypass_cmd_link_o[W] = cmd_concentrated_link_lo;
            resp_concentrated_link_li = bypass_resp_link_i[W];
          end
        default: // e_dram_bypass_east
          begin
            bypass_cmd_link_o[E] = cmd_concentrated_link_lo;
            resp_concentrated_link_li = bypass_resp_link_i[E];
          end
      endcase
    end

// synopsys translate_off
always_ff @(negedge mem_clk_i)
  assert (dram_mode_li != e_dram_enable) else $error("DMC is not current supported");
// synopsys translate_on

endmodule

