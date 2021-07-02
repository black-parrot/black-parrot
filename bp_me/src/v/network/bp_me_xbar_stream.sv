
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

// Command arbitration logic
// This is suboptimal. We could have an arbiter for each source, to get higher
//   throughput. So far this isn't a bottle neck, and this approach is less hardware.
module bp_me_xbar_stream
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter data_width_p  = "inv"
   , parameter num_source_p = "inv"
   , parameter num_sink_p   = "inv"
   `declare_bp_bedrock_mem_if_widths(paddr_width_p, data_width_p, lce_id_width_p, lce_assoc_p, uce)

   , localparam lg_num_source_lp = `BSG_SAFE_CLOG2(num_source_p)
   , localparam lg_num_sink_lp   = `BSG_SAFE_CLOG2(num_sink_p)
   )
  (input                                                              clk_i
   , input                                                            reset_i

   , input [num_source_p-1:0][uce_mem_msg_header_width_lp-1:0]        cmd_header_i
   , input [num_source_p-1:0][data_width_p-1:0]                       cmd_data_i
   , input [num_source_p-1:0]                                         cmd_v_i
   , output logic [num_source_p-1:0]                                  cmd_yumi_o
   , input [num_source_p-1:0]                                         cmd_last_i
   , input [num_source_p-1:0][lg_num_sink_lp-1:0]                     cmd_dst_i

   , output logic [num_source_p-1:0][uce_mem_msg_header_width_lp-1:0] resp_header_o
   , output logic [num_source_p-1:0][data_width_p-1:0]                resp_data_o
   , output logic [num_source_p-1:0]                                  resp_v_o
   , input [num_source_p-1:0]                                         resp_ready_and_i
   , output logic [num_source_p-1:0]                                  resp_last_o

   , output logic [num_sink_p-1:0][uce_mem_msg_header_width_lp-1:0]   cmd_header_o
   , output logic [num_sink_p-1:0][data_width_p-1:0]                  cmd_data_o
   , output logic [num_sink_p-1:0]                                    cmd_v_o
   , input [num_sink_p-1:0]                                           cmd_ready_and_i
   , output logic [num_sink_p-1:0]                                    cmd_last_o

   , input [num_sink_p-1:0][uce_mem_msg_header_width_lp-1:0]          resp_header_i
   , input [num_sink_p-1:0][data_width_p-1:0]                         resp_data_i
   , input [num_sink_p-1:0]                                           resp_v_i
   , output logic [num_sink_p-1:0]                                    resp_yumi_o
   , input [num_sink_p-1:0]                                           resp_last_i
   , input [num_sink_p-1:0][lg_num_source_lp-1:0]                     resp_dst_i
   );

  `declare_bp_bedrock_mem_if(paddr_width_p, data_width_p, lce_id_width_p, lce_assoc_p, uce);

  // cmd arbitration logic
  logic [num_source_p-1:0] cmd_grants_lo;
  wire cmd_arb_unlock_li = |{cmd_yumi_o & cmd_last_i} | reset_i;
  bsg_locking_arb_fixed
   #(.inputs_p(num_source_p), .lo_to_hi_p(0))
   cmd_arbiter
    (.clk_i(clk_i)
     ,.ready_i(1'b1)

     ,.unlock_i(cmd_arb_unlock_li)
     ,.reqs_i(cmd_v_i)
     ,.grants_o(cmd_grants_lo)
     );
  logic [lg_num_source_lp-1:0] cmd_grants_sel_li;
  logic cmd_grants_v_li;
  bsg_encode_one_hot
   #(.width_p(num_source_p), .lo_to_hi_p(1))
   cmd_sel
    (.i(cmd_grants_lo)
     ,.addr_o(cmd_grants_sel_li)
     ,.v_o(cmd_grants_v_li)
     );

  bp_bedrock_uce_mem_msg_header_s cmd_header_selected_lo;
  bsg_mux_one_hot
   #(.width_p($bits(bp_bedrock_uce_mem_msg_header_s)), .els_p(num_source_p))
   cmd_header_select
    (.data_i(cmd_header_i)
     ,.sel_one_hot_i(cmd_grants_lo)
     ,.data_o(cmd_header_selected_lo)
     );
  logic [data_width_p-1:0] cmd_data_selected_lo;
  bsg_mux_one_hot
   #(.width_p(data_width_p), .els_p(num_source_p))
   cmd_data_select
    (.data_i(cmd_data_i)
     ,.sel_one_hot_i(cmd_grants_lo)
     ,.data_o(cmd_data_selected_lo)
     );
  assign cmd_header_o = {num_sink_p{cmd_header_selected_lo}};
  assign cmd_data_o   = {num_sink_p{cmd_data_selected_lo}};
  assign cmd_v_o      = cmd_grants_v_li ? (1'b1 << cmd_dst_i[cmd_grants_sel_li]) : '0;
  assign cmd_yumi_o   = cmd_grants_lo & {num_source_p{|{cmd_v_o & cmd_ready_and_i}}};
  assign cmd_last_o   = cmd_v_o & cmd_last_i[cmd_grants_sel_li];

  // Response arbitration logic
  logic [num_sink_p-1:0] resp_grant_li;
  wire resp_arb_unlock_li = reset_i | |{resp_yumi_o & resp_last_i};
  bsg_locking_arb_fixed
   #(.inputs_p(num_sink_p), .lo_to_hi_p(1))
   resp_arbiter
    (.clk_i(clk_i)
     ,.ready_i(1'b1)

     ,.unlock_i(resp_arb_unlock_li)
     ,.reqs_i(resp_v_i)
     ,.grants_o(resp_grant_li)
     );
  logic [lg_num_sink_lp-1:0] resp_grant_sel_li;
  logic resp_grant_v_li;
  bsg_encode_one_hot
   #(.width_p(num_sink_p), .lo_to_hi_p(1))
   resp_sel
    (.i(resp_grant_li)
     ,.addr_o(resp_grant_sel_li)
     ,.v_o(resp_grant_v_li)
     );

  bp_bedrock_uce_mem_msg_header_s resp_header_lo;
  logic [data_width_p-1:0] resp_data_lo;
  bsg_mux_one_hot
   #(.width_p($bits(bp_bedrock_uce_mem_msg_header_s)), .els_p(num_sink_p))
   resp_header_select
    (.data_i(resp_header_i)
     ,.sel_one_hot_i(resp_grant_li)
     ,.data_o(resp_header_lo)
     );
  bsg_mux_one_hot
  #(.width_p(data_width_p), .els_p(num_sink_p))
  resp_data_select
   (.data_i(resp_data_i)
    ,.sel_one_hot_i(resp_grant_li)
    ,.data_o(resp_data_lo)
    );
  assign resp_header_o = {num_source_p{resp_header_lo}};
  assign resp_data_o   = {num_source_p{resp_data_lo}};
  assign resp_v_o      = resp_grant_v_li ? (1'b1 << resp_dst_i[resp_grant_sel_li]) : '0;
  assign resp_yumi_o   = resp_grant_li & {num_sink_p{|{resp_v_o & resp_ready_and_i}}};
  assign resp_last_o   = resp_v_o & resp_last_i[resp_grant_sel_li];

endmodule

