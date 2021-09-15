/**
 *
 * Name:
 *   bp_me_xbar_stream.sv
 *
 * Description:
 *   This xbar arbitrates BedRock Stream messages between N sources and M sinks.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_xbar_stream
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter data_width_p    = "inv"
   , parameter payload_width_p = "inv"
   , parameter num_source_p    = "inv"
   , parameter num_sink_p      = "inv"
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, data_width_p, lce_id_width_p, lce_assoc_p, xbar)

   , localparam lg_num_source_lp = `BSG_SAFE_CLOG2(num_source_p)
   , localparam lg_num_sink_lp   = `BSG_SAFE_CLOG2(num_sink_p)
   )
  (input                                                              clk_i
   , input                                                            reset_i

   , input [num_source_p-1:0][xbar_msg_header_width_lp-1:0]           msg_header_i
   , input [num_source_p-1:0][data_width_p-1:0]                       msg_data_i
   , input [num_source_p-1:0]                                         msg_v_i
   , output logic [num_source_p-1:0]                                  msg_yumi_o
   , input [num_source_p-1:0]                                         msg_last_i
   , input [num_source_p-1:0][lg_num_sink_lp-1:0]                     msg_dst_i

   , output logic [num_sink_p-1:0][xbar_msg_header_width_lp-1:0]      msg_header_o
   , output logic [num_sink_p-1:0][data_width_p-1:0]                  msg_data_o
   , output logic [num_sink_p-1:0]                                    msg_v_o
   , input [num_sink_p-1:0]                                           msg_ready_and_i
   , output logic [num_sink_p-1:0]                                    msg_last_o
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, data_width_p, lce_id_width_p, lce_assoc_p, xbar);

  // msg arbitration logic
  logic [num_source_p-1:0] msg_grants_lo;
  wire msg_arb_unlock_li = |{msg_yumi_o & msg_last_i} | reset_i;
  bsg_locking_arb_fixed
   #(.inputs_p(num_source_p), .lo_to_hi_p(0))
   msg_arbiter
    (.clk_i(clk_i)
     ,.ready_i(1'b1)

     ,.unlock_i(msg_arb_unlock_li)
     ,.reqs_i(msg_v_i)
     ,.grants_o(msg_grants_lo)
     );
  logic [lg_num_source_lp-1:0] msg_grants_sel_li;
  logic msg_grants_v_li;
  bsg_encode_one_hot
   #(.width_p(num_source_p), .lo_to_hi_p(1))
   msg_sel
    (.i(msg_grants_lo)
     ,.addr_o(msg_grants_sel_li)
     ,.v_o(msg_grants_v_li)
     );

  bp_bedrock_xbar_msg_header_s msg_header_selected_lo;
  bsg_mux_one_hot
   #(.width_p($bits(bp_bedrock_xbar_msg_header_s)), .els_p(num_source_p))
   msg_header_select
    (.data_i(msg_header_i)
     ,.sel_one_hot_i(msg_grants_lo)
     ,.data_o(msg_header_selected_lo)
     );
  logic [data_width_p-1:0] msg_data_selected_lo;
  bsg_mux_one_hot
   #(.width_p(data_width_p), .els_p(num_source_p))
   msg_data_select
    (.data_i(msg_data_i)
     ,.sel_one_hot_i(msg_grants_lo)
     ,.data_o(msg_data_selected_lo)
     );
  assign msg_header_o = {num_sink_p{msg_header_selected_lo}};
  assign msg_data_o   = {num_sink_p{msg_data_selected_lo}};
  assign msg_v_o      = msg_grants_v_li ? (1'b1 << msg_dst_i[msg_grants_sel_li]) : '0;
  assign msg_yumi_o   = msg_grants_lo & {num_source_p{|{msg_v_o & msg_ready_and_i}}};
  assign msg_last_o   = msg_v_o & {num_sink_p{msg_last_i[msg_grants_sel_li]}};

endmodule

