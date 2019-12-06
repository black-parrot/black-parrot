
module bp_me_cce_to_cache_buffered
  import bp_cce_pkg::*;
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_me_pkg::*;
  import bsg_cache_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_inv_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_me_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p)

   , parameter bsg_cache_pkt_width_lp=`bsg_cache_pkt_width(paddr_width_p, dword_width_p)
   )
  (input clk_i
   , input reset_i

   // cce size
   , input  [cce_mem_msg_width_lp-1:0]   mem_cmd_i
   , input                               mem_cmd_v_i
   , output                              mem_cmd_ready_o
                                         
   , output [cce_mem_msg_width_lp-1:0]   mem_resp_o
   , output                              mem_resp_v_o
   , input                               mem_resp_yumi_i

   // cache-side
   , output [bsg_cache_pkt_width_lp-1:0] cache_pkt_o
   , output logic                        v_o
   , input                               ready_i

   , input [dword_width_p-1:0]           data_i
   , input                               v_i
   , output logic                        yumi_o
   );

  `declare_bp_me_if(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p);

  bp_cce_mem_msg_s mem_cmd_li;
  logic mem_cmd_v_li, mem_cmd_yumi_lo;

  bp_cce_mem_msg_s mem_resp_lo;
  logic mem_resp_v_lo, mem_resp_ready_li;

  bp_me_cce_to_cache
   #(.bp_params_p(bp_params_p))
   cce_to_cache
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.mem_cmd_i(mem_cmd_li)
     ,.mem_cmd_v_i(mem_cmd_v_li)
     ,.mem_cmd_yumi_o(mem_cmd_yumi_lo)

     ,.mem_resp_o(mem_resp_lo)
     ,.mem_resp_v_o(mem_resp_v_lo)
     ,.mem_resp_ready_i(mem_resp_ready_li)

     ,.cache_pkt_o(cache_pkt_o)
     ,.v_o(v_o)
     ,.ready_i(ready_i)

     ,.data_i(data_i)
     ,.v_i(v_i)
     ,.yumi_o(yumi_o)
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

