
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_bedrock_register
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce)

   , parameter reg_width_p = dword_width_gp
   , parameter reg_addr_width_p = paddr_width_p
   , parameter els_p = 1
   , parameter integer base_addr_p [els_p-1:0] = '0
   )
  (input                                            clk_i
   , input                                          reset_i

   , input [xce_mem_msg_header_width_lp-1:0]        mem_cmd_header_i
   , input [dword_width_gp-1:0]                     mem_cmd_data_i
   , input                                          mem_cmd_v_i
   , output logic                                   mem_cmd_ready_and_o

   , output logic [xce_mem_msg_header_width_lp-1:0] mem_resp_header_o
   , output logic [dword_width_gp-1:0]              mem_resp_data_o
   , output logic                                   mem_resp_v_o
   , input                                          mem_resp_ready_and_i


   // Synchronous read/write interface.
   // Actually 1rw, but expose both ports to prevent unnecessary and gates
   , output logic [els_p-1:0]                       r_v_o
   , output logic [els_p-1:0]                       w_v_o
   , output logic [reg_addr_width_p-1:0]            addr_o
   , output logic [reg_width_p-1:0]                 data_o
   , input [els_p-1:0][reg_width_p-1:0]             data_i
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, dword_width_gp, lce_id_width_p, lce_assoc_p, xce);

  bp_bedrock_xce_mem_msg_header_s mem_cmd_header_li;
  logic [dword_width_gp-1:0] mem_cmd_data_li;
  logic mem_cmd_v_li, mem_cmd_yumi_li;
  bsg_one_fifo
   #(.width_p($bits(bp_bedrock_xce_mem_msg_s)))
   header_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
  
     ,.data_i({mem_cmd_data_i, mem_cmd_header_i})
     ,.v_i(mem_cmd_v_i)
     ,.ready_o(mem_cmd_ready_and_o)
  
     ,.data_o({mem_cmd_data_li, mem_cmd_header_li})
     ,.v_o(mem_cmd_v_li)
     ,.yumi_i(mem_cmd_yumi_li)
     );

  logic [els_p-1:0] r_v_r;
  bsg_dff
   #(.width_p(els_p))
   v_reg
    (.clk_i(clk_i)
     ,.data_i(r_v_o)
     ,.data_o(r_v_r)
     );

  logic [reg_width_p-1:0] rdata_lo;
  bsg_mux_one_hot
   #(.width_p(reg_width_p), .els_p(els_p))
   rmux_oh
    (.data_i(data_i)
     ,.sel_one_hot_i(r_v_r)
     ,.data_o(rdata_lo)
     );

      wire wr_not_rd  = (mem_cmd_header_li.msg_type inside {e_bedrock_mem_wr, e_bedrock_mem_uc_wr});
  for (genvar i = 0; i < els_p; i++)
    begin : dec
      wire addr_match = mem_cmd_v_li & (mem_cmd_header_li.addr inside {base_addr_p[i]});
      assign r_v_o[i] = addr_match & ~wr_not_rd;
      assign w_v_o[i] = addr_match &  wr_not_rd;
    end
      assign addr_o = (mem_cmd_header_li.addr);
      assign data_o = (mem_cmd_data_li);

  assign mem_resp_header_o = mem_cmd_header_li;
  assign mem_resp_data_o = rdata_lo;
  assign mem_resp_v_o = mem_cmd_v_li & (|r_v_r | wr_not_rd);
  assign mem_cmd_yumi_li = mem_resp_ready_and_i & mem_resp_v_o;

endmodule

