/**
 *
 * Name:
 *   bp_me_xbar_stream_bidir.sv
 *
 * Description:
 *   This xbar arbitrates paired BedRock Stream command/response channels between
 *   N sources and M sinks.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_xbar_stream_bidir
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

   , input [num_source_p-1:0][xbar_msg_header_width_lp-1:0]           cmd_header_i
   , input [num_source_p-1:0][data_width_p-1:0]                       cmd_data_i
   , input [num_source_p-1:0]                                         cmd_v_i
   , output logic [num_source_p-1:0]                                  cmd_yumi_o
   , input [num_source_p-1:0]                                         cmd_last_i
   , input [num_source_p-1:0][lg_num_sink_lp-1:0]                     cmd_dst_i

   , output logic [num_source_p-1:0][xbar_msg_header_width_lp-1:0]    resp_header_o
   , output logic [num_source_p-1:0][data_width_p-1:0]                resp_data_o
   , output logic [num_source_p-1:0]                                  resp_v_o
   , input [num_source_p-1:0]                                         resp_ready_and_i
   , output logic [num_source_p-1:0]                                  resp_last_o

   , output logic [num_sink_p-1:0][xbar_msg_header_width_lp-1:0]      cmd_header_o
   , output logic [num_sink_p-1:0][data_width_p-1:0]                  cmd_data_o
   , output logic [num_sink_p-1:0]                                    cmd_v_o
   , input [num_sink_p-1:0]                                           cmd_ready_and_i
   , output logic [num_sink_p-1:0]                                    cmd_last_o

   , input [num_sink_p-1:0][xbar_msg_header_width_lp-1:0]             resp_header_i
   , input [num_sink_p-1:0][data_width_p-1:0]                         resp_data_i
   , input [num_sink_p-1:0]                                           resp_v_i
   , output logic [num_sink_p-1:0]                                    resp_yumi_o
   , input [num_sink_p-1:0]                                           resp_last_i
   , input [num_sink_p-1:0][lg_num_source_lp-1:0]                     resp_dst_i
   );

  // command channel - N:M
  bp_me_xbar_stream
   #(.data_width_p(data_width_p)
     ,.payload_width_p(payload_width_p)
     ,.num_source_p(num_source_p)
     ,.num_sink_p(num_sink_p)
     )
   cmd_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(cmd_header_i)
     ,.msg_data_i(cmd_data_i)
     ,.msg_v_i(cmd_v_i)
     ,.msg_yumi_o(cmd_yumi_o)
     ,.msg_last_i(cmd_last_i)
     ,.msg_dst_i(cmd_dst_i)

     ,.msg_header_o(cmd_header_o)
     ,.msg_data_o(cmd_data_o)
     ,.msg_v_o(cmd_v_o)
     ,.msg_ready_and_i(cmd_ready_and_i)
     ,.msg_last_o(cmd_last_o)
     );

  // response channel - M:N
  // source and sink params are inverted for response xbar to do sink to source arbitration
  bp_me_xbar_stream
   #(.data_width_p(data_width_p)
     ,.payload_width_p(payload_width_p)
     ,.num_source_p(num_sink_p)
     ,.num_sink_p(num_source_p)
     )
   resp_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(resp_header_i)
     ,.msg_data_i(resp_data_i)
     ,.msg_v_i(resp_v_i)
     ,.msg_yumi_o(resp_yumi_o)
     ,.msg_last_i(resp_last_i)
     ,.msg_dst_i(resp_dst_i)

     ,.msg_header_o(resp_header_o)
     ,.msg_data_o(resp_data_o)
     ,.msg_v_o(resp_v_o)
     ,.msg_ready_and_i(resp_ready_and_i)
     ,.msg_last_o(resp_last_o)
     );

endmodule

