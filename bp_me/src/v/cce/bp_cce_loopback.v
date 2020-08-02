
//
// This module is an active tie-off. That is, requests to this module will return the header
//   with a zero payload. This is useful to not stall the network in the case of an erroneous
//   address, or prevent deadlock at network boundaries
module bp_cce_loopback
  import bp_common_pkg::*;
  import bp_common_aviary_pkg::*;
  import bp_cce_pkg::*;
  import bp_common_cfg_link_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)
    `declare_bp_mem_if_widths(paddr_width_p, cce_block_width_p, lce_id_width_p, lce_assoc_p, cce_mem)
    )
   (input                                           clk_i
    , input                                         reset_i

    , input [cce_mem_msg_width_lp-1:0]              mem_cmd_i
    , input                                         mem_cmd_v_i
    , output                                        mem_cmd_ready_o

    , output [cce_mem_msg_width_lp-1:0]             mem_resp_o
    , output                                        mem_resp_v_o
    , input                                         mem_resp_yumi_i
    );

  `declare_bp_mem_if(paddr_width_p, dword_width_p, lce_id_width_p, lce_assoc_p, cce_mem);

  bp_cce_mem_msg_s mem_cmd_cast_i;
  bp_cce_mem_msg_s mem_resp_cast_o;

  assign mem_cmd_cast_i = mem_cmd_i;
  assign mem_resp_o = mem_resp_cast_o;

  bsg_two_fifo
   #(.width_p($bits(mem_cmd_cast_i.header)))
   loopback_buffer
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i(mem_cmd_cast_i.header)
     ,.v_i(mem_cmd_v_i)
     ,.ready_o(mem_cmd_ready_o)

     ,.data_o(mem_resp_cast_o.header)
     ,.v_o(mem_resp_v_o)
     ,.yumi_i(mem_resp_yumi_i)
     );
  assign mem_resp_cast_o.data = '0;

endmodule

