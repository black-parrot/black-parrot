
module bp_rerouter
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_be_pkg::*;
 import bp_common_cfg_link_pkg::*;
 import bp_cce_pkg::*;
 import bsg_noc_pkg::*;
 import bsg_wormhole_router_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p)

   , localparam mem_noc_ral_link_width_lp = `bsg_ready_and_link_sif_width(mem_noc_flit_width_p)
   )
  (input                                                clk_i
   , input                                              reset_i

   // BP side
   , input [mem_noc_chid_width_p-1:0]                   my_chid_i
   , input [mem_noc_cord_width_p-1:0]                   my_cord_i

   , input [mem_noc_ral_link_width_lp-1:0]              mem_cmd_link_i
   , output [mem_noc_ral_link_width_lp-1:0]             mem_cmd_link_o

   , input [mem_noc_ral_link_width_lp-1:0]              mem_resp_link_i
   , output [mem_noc_ral_link_width_lp-1:0]             mem_resp_link_o
   );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, num_lce_p, lce_assoc_p);

  bp_cce_mem_msg_s mem_cmd_li;
  logic mem_cmd_v_li, mem_cmd_yumi_lo;
  bp_cce_mem_msg_s mem_resp_lo;
  logic mem_resp_v_lo, mem_resp_ready_li;

  bp_cce_mem_msg_s mem_cmd_lo;
  logic mem_cmd_v_lo, mem_cmd_ready_li;
  bp_cce_mem_msg_s mem_resp_li;
  logic mem_resp_v_li, mem_resp_yumi_lo;

  logic [mem_noc_cord_width_p-1:0] dst_cord_lo;
  logic [mem_noc_cid_width_p-1:0]  dst_cid_lo;

  wire [mem_noc_chid_width_p-1:0] incoming_chid_li = mem_cmd_li.addr[paddr_width_p-1-:mem_noc_chid_width_p];
  wire chid_match_li = (incoming_chid_li == my_chid_i);

  // TODO: Add concurrency 
  bp_me_cce_to_wormhole_link_bidir
   #(.bp_params_p(bp_params_p))
   rerouter_link
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.my_cord_i(my_cord_i)
     ,.my_cid_i('0)
  
     ,.mem_cmd_o(mem_cmd_li)
     ,.mem_cmd_v_o(mem_cmd_v_li)
     ,.mem_cmd_yumi_i(mem_cmd_yumi_lo)
  
     ,.mem_resp_i(mem_resp_lo)
     ,.mem_resp_v_i(mem_resp_v_lo)
     ,.mem_resp_ready_o(mem_resp_ready_li)
  
     ,.dst_cord_i(dst_cord_lo)
     ,.dst_cid_i(dst_cid_lo)
  
     ,.mem_cmd_i(mem_cmd_lo)
     ,.mem_cmd_v_i(mem_cmd_v_lo)
     ,.mem_cmd_ready_o(mem_cmd_ready_li)
  
     ,.mem_resp_o(mem_resp_li)
     ,.mem_resp_v_o(mem_resp_v_li)
     ,.mem_resp_yumi_i(mem_resp_yumi_lo)
  
     ,.cmd_link_i(mem_cmd_link_i)
     ,.cmd_link_o(mem_cmd_link_o)
  
     ,.resp_link_i(mem_resp_link_i)
     ,.resp_link_o(mem_resp_link_o)
     );

endmodule

