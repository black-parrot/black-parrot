/**
 *
 * Name:
 *   bp_me_xbar_stream_buffered.sv
 *
 * Description:
 *   This xbar arbitrates BedRock Stream messages between N sources and M sinks.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_xbar_stream_buffered
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(payload_width_p)
   , parameter `BSG_INV_PARAM(num_source_p)
   , parameter `BSG_INV_PARAM(num_sink_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, data_width_p, lce_id_width_p, lce_assoc_p, xbar)

   , localparam lg_num_source_lp = `BSG_SAFE_CLOG2(num_source_p)
   , localparam lg_num_sink_lp   = `BSG_SAFE_CLOG2(num_sink_p)
   )
  (input                                                              clk_i
   , input                                                            reset_i

   , input [num_source_p-1:0][xbar_msg_header_width_lp-1:0]           msg_header_i
   , input [num_source_p-1:0][data_width_p-1:0]                       msg_data_i
   , input [num_source_p-1:0]                                         msg_v_i
   , output logic [num_source_p-1:0]                                  msg_ready_and_o
   , input [num_source_p-1:0]                                         msg_last_i
   , input [num_source_p-1:0][lg_num_sink_lp-1:0]                     msg_dst_i

   , output logic [num_sink_p-1:0][xbar_msg_header_width_lp-1:0]      msg_header_o
   , output logic [num_sink_p-1:0][data_width_p-1:0]                  msg_data_o
   , output logic [num_sink_p-1:0]                                    msg_v_o
   , input [num_sink_p-1:0]                                           msg_ready_and_i
   , output logic [num_sink_p-1:0]                                    msg_last_o
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, data_width_p, lce_id_width_p, lce_assoc_p, xbar);
  bp_bedrock_xbar_msg_header_s [num_source_p-1:0] msg_header_li;
  logic [num_source_p-1:0][data_width_p-1:0] msg_data_li;
  logic [num_source_p-1:0] msg_v_li, msg_yumi_lo, msg_last_li;
  logic [num_source_p-1:0][lg_num_sink_lp-1:0] msg_dst_li;

  for (genvar i = 0; i < num_source_p; i++)
    begin : buffer
      bsg_two_fifo
       #(.width_p(lg_num_sink_lp+1+data_width_p+xbar_msg_header_width_lp))
       in_fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i({msg_dst_i[i], msg_last_i[i], msg_data_i[i], msg_header_i[i]})
         ,.v_i(msg_v_i[i])
         ,.ready_o(msg_ready_and_o[i])

         ,.data_o({msg_dst_li[i], msg_last_li[i], msg_data_li[i], msg_header_li[i]})
         ,.v_o(msg_v_li[i])
         ,.yumi_i(msg_yumi_lo[i])
         );
    end

  bp_me_xbar_stream
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(data_width_p)
     ,.payload_width_p(payload_width_p)
     ,.num_source_p(num_source_p)
     ,.num_sink_p(num_sink_p)
     )
   cmd_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i(msg_header_li)
     ,.msg_data_i(msg_data_li)
     ,.msg_v_i(msg_v_li)
     ,.msg_yumi_o(msg_yumi_lo)
     ,.msg_last_i(msg_last_li)
     ,.msg_dst_i(msg_dst_li)

     ,.*
     );

endmodule

`BSG_ABSTRACT_MODULE(bp_me_xbar_stream_buffered)

