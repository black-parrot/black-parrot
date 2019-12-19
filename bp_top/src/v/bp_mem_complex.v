
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
   , localparam bypass_link_width_lp = `bsg_ready_and_link_sif_width(bypass_flit_width_p)
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

   , output [E:W][bypass_link_width_lp-1:0]                  bypass_cmd_link_o
   , input [E:W][bypass_link_width_lp-1:0]                   bypass_resp_link_i

   // TODO: DMC links
   );

  `declare_bp_cfg_bus_s(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p);
  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)
  `declare_bp_lce_cce_if(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
  `declare_bsg_ready_and_link_sif_s(coh_noc_flit_width_p, bp_coh_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(io_noc_flit_width_p, bp_io_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(mem_noc_flit_width_p, bp_mem_ready_and_link_s);
  `declare_bsg_ready_and_link_sif_s(bypass_flit_width_p, bp_bypass_ready_and_link_s);

  bp_mem_ready_and_link_s [S:N][mc_x_dim_p-1:0] mem_cmd_link_li, mem_cmd_link_lo;
  bp_mem_ready_and_link_s [S:N][mc_x_dim_p-1:0] mem_resp_link_li, mem_resp_link_lo;

  // Right now this is passthrough, but should be replaced by l2e tiles
  assign coh_req_link_o  = '0;
  assign coh_cmd_link_o  = '0;

  assign mem_cmd_link_lo[S]  = mem_cmd_link_i;
  assign mem_resp_link_o     = mem_resp_link_li[S];

  bp_mem_ready_and_link_s cmd_concentrated_link_lo, resp_concentrated_link_li;;
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

     ,.cmd_link_i(cmd_concentrated_link_lo)
     ,.resp_link_o(resp_concentrated_link_li)
     );

  localparam bypass_len_lp = `BSG_CDIV(cce_mem_msg_width_lp, bypass_flit_width_p);
  localparam bypass_width_ceil_lp = bypass_len_lp * bypass_flit_width_p;
  bp_cce_mem_msg_s piso_cmd_li;
  logic piso_cmd_v_li, piso_cmd_ready_lo;
  bp_bypass_ready_and_link_s bypass_cmd_link_lo;
  wire [bypass_width_ceil_lp-1:0] piso_cmd_pad_li = bypass_width_ceil_lp'(piso_cmd_li);
  bsg_parallel_in_serial_out
   #(.width_p(bypass_flit_width_p)
     ,.els_p(bypass_len_lp)
     )
   bypass_cmd_piso
    (.clk_i(mem_clk_i)
     ,.reset_i(mem_reset_i)

     ,.data_i(piso_cmd_pad_li)
     ,.valid_i(piso_cmd_v_li)
     ,.ready_o(piso_cmd_ready_lo)

     ,.data_o(bypass_cmd_link_lo.data)
     ,.valid_o(bypass_cmd_link_lo.v)
     ,.yumi_i(bypass_resp_link_li.ready_and_rev & bypass_cmd_link_lo.v)
     );

  bp_cce_mem_msg_s sipo_resp_lo;
  logic sipo_resp_v_lo, sipo_resp_yumi_li;
  bp_bypass_ready_and_link_s bypass_resp_link_li;
  logic [bypass_width_ceil_lp-1:0] sipo_resp_pad_lo;
  bsg_serial_in_parallel_out_full
   #(.width_p(bypass_flit_width_p)
     ,.els_p(bypass_len_lp)
     ,.use_minimal_buffering_p(1)
     )
   bypass_resp_sipo
    (.clk_i(mem_clk_i)
     ,.reset_i(mem_reset_i)

     ,.data_i(bypass_resp_link_li.data)
     ,.v_i(bypass_resp_link_li.v)
     ,.ready_o(bypass_cmd_link_lo.ready_and_rev)

     ,.data_o(sipo_resp_pad_lo)
     ,.v_o(sipo_resp_v_lo)
     ,.yumi_i(sipo_resp_yumi_li)
     );
  assign sipo_resp_lo = sipo_resp_pad_lo[0+:cce_mem_msg_width_lp];

  typedef enum bit [1:0]
  {
    e_dram_bypass_east  = 2'b00
    ,e_dram_bypass_west = 2'b01
    ,e_dram_enable      = 2'b11
  } dram_mode_e;

  dram_mode_e dram_mode_li;
  assign dram_mode_li = e_dram_bypass_east;

  assign bypass_cmd_link_o[E] = (dram_mode_li == e_dram_bypass_east) ? bypass_cmd_link_lo : '0;
  assign bypass_cmd_link_o[W] = (dram_mode_li == e_dram_bypass_west) ? bypass_cmd_link_lo : '0;
  assign bypass_resp_link_li  = (dram_mode_li == e_dram_bypass_east) ? bypass_resp_link_i[E] : bypass_resp_link_i[W];

  always_comb
    begin
      piso_cmd_li = '0;
      piso_cmd_v_li = '0;
      dram_cmd_yumi_li = '0;
      dram_resp_li = '0;
      dram_resp_v_li = '0;
      sipo_resp_yumi_li = '0;

      case (dram_mode_li)
        e_dram_enable: begin end
        e_dram_bypass_east, e_dram_bypass_west:
          begin
            piso_cmd_li = dram_cmd_lo;
            piso_cmd_v_li = dram_cmd_v_lo;
            dram_cmd_yumi_li = piso_cmd_ready_lo & piso_cmd_v_li;

            dram_resp_li = sipo_resp_lo;
            dram_resp_v_li = sipo_resp_v_lo;
            sipo_resp_yumi_li = dram_resp_ready_lo & sipo_resp_v_lo;
          end

      endcase
    end

always_ff @(negedge mem_clk_i)
  assert (dram_mode_li != e_dram_enable) else $error("DMC is not current supported");
  
endmodule

