
module bp_cfg_buffered
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_rv64_pkg::*;
 import bp_cce_pkg::*;
 import bp_common_cfg_link_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   , localparam cfg_bus_width_lp = `bp_cfg_bus_width(vaddr_width_p, core_id_width_p, cce_id_width_p, lce_id_width_p, cce_pc_width_p, cce_instr_width_p)
   )
  (input                                clk_i
   , input                              reset_i

   , input [cce_mem_msg_width_lp-1:0]   mem_cmd_i
   , input                              mem_cmd_v_i
   , output                             mem_cmd_ready_o

   , output [cce_mem_msg_width_lp-1:0]  mem_resp_o
   , output                             mem_resp_v_o
   , input                              mem_resp_yumi_i

   , output [cfg_bus_width_lp-1:0]      cfg_bus_o
   , input [coh_noc_cord_width_p-1:0]   cord_i
   , input [io_noc_did_width_p-1:0]     did_i
   , input [dword_width_p-1:0]          irf_data_i
   , input [vaddr_width_p-1:0]          npc_data_i
   , input                              haz_v_i
   , input [dword_width_p-1:0]          csr_data_i
   , input [1:0]                        priv_data_i
   , input [cce_instr_width_p-1:0]      cce_ucode_data_i
   );

`declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

bp_cce_mem_msg_s mem_cmd_li;
logic mem_cmd_v_li, mem_cmd_yumi_lo;

bp_cce_mem_msg_s mem_resp_lo;
logic mem_resp_v_lo, mem_resp_ready_li;

bp_cfg
 #(.bp_params_p(bp_params_p))
 cfg
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.mem_cmd_i(mem_cmd_li)
   ,.mem_cmd_v_i(mem_cmd_v_li)
   ,.mem_cmd_yumi_o(mem_cmd_yumi_lo)

   ,.mem_resp_o(mem_resp_lo)
   ,.mem_resp_v_o(mem_resp_v_lo)
   ,.mem_resp_ready_i(mem_resp_ready_li)

   ,.cfg_bus_o(cfg_bus_o)
   ,.cord_i(cord_i)
   ,.did_i(did_i)
   ,.irf_data_i(irf_data_i)
   ,.npc_data_i(npc_data_i)
   ,.haz_v_i(haz_v_i)
   ,.csr_data_i(csr_data_i)
   ,.priv_data_i(priv_data_i)
   ,.cce_ucode_data_i(cce_ucode_data_i)
   );

bsg_two_fifo
 #(.width_p($bits(bp_cce_mem_msg_s)))
 cmd_buffer
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(mem_cmd_i)
   ,.v_i(mem_cmd_v_i)
   ,.ready_o(mem_cmd_ready_o)

   ,.data_o(mem_cmd_li)
   ,.v_o(mem_cmd_v_li)
   ,.yumi_i(mem_cmd_yumi_lo)
   );

bsg_two_fifo
 #(.width_p($bits(bp_cce_mem_msg_s)))
 resp_buffer
  (.clk_i(clk_i)
   ,.reset_i(reset_i)

   ,.data_i(mem_resp_lo)
   ,.v_i(mem_resp_v_lo)
   ,.ready_o(mem_resp_ready_li)

   ,.data_o(mem_resp_o)
   ,.v_o(mem_resp_v_o)
   ,.yumi_i(mem_resp_yumi_i)
   );

endmodule

