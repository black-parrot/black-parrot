
module bp_io_tile
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_cce_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_lce_cce_if_widths(cce_id_width_p, lce_id_width_p, paddr_width_p, lce_assoc_p, dword_width_p, cce_block_width_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   , localparam coh_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(coh_noc_flit_width_p)
   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                    clk_i
   , input                                  reset_i

   , input [cce_id_width_p-1:0]             cce_id_i

   , input [mem_noc_ral_link_width_lp-1:0]  io_cmd_link_i
   , output [mem_noc_ral_link_width_lp-1:0] io_cmd_link_o

   , input [mem_noc_ral_link_width_lp-1:0]  io_resp_link_i
   , output [mem_noc_ral_link_width_lp-1:0] io_resp_link_o

   , input [coh_noc_ral_link_width_lp-1:0]  lce_req_link_i
   , output [coh_noc_ral_link_width_lp-1:0] lce_req_link_o

   , input [coh_noc_ral_link_width_lp-1:0]  lce_cmd_link_i
   , output [coh_noc_ral_link_width_lp-1:0] lce_cmd_link_o
   );

   bp_io_link_to_lce
    #(.bp_params_p(bp_params_p))
    lce_link
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.lce_id_i()

      ,.io_cmd_i()
      ,.io_cmd_v_i()
      ,.io_cmd_yumi_o()

      ,.io_resp_o()
      ,.io_resp_v_o()
      ,.io_resp_ready_i()

      ,.lce_req_o()
      ,.lce_req_v_o()
      ,.lce_req_ready_i()

      ,.lce_cmd_i()
      ,.lce_cmd_v_i()
      ,.lce_cmd_yumi_o()
      );

   bp_io_cce
    #(.bp_params_p(bp_params_p))
    io_cce
     (.clk_i(clk_i)
      ,.reset_i(reset_i)

      ,.cce_id_i()

      ,.lce_req_i()
      ,.lce_req_v_i()
      ,.lce_req_yumi_o()

      ,.lce_cmd_o()
      ,.lce_cmd_v_o()
      ,.lce_cmd_ready_i()

      ,.mem_cmd_o()
      ,.mem_cmd_v_o()
      ,.mem_cmd_ready_i()

      ,.mem_resp_i()
      ,.mem_resp_v_i()
      ,.mem_resp_yumi_o()
      );


endmodule

