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

   , parameter `BSG_INV_PARAM(payload_width_p)
   , parameter `BSG_INV_PARAM(payload_mask_p)
   , parameter `BSG_INV_PARAM(num_source_p)
   , parameter `BSG_INV_PARAM(num_sink_p)

   , parameter `BSG_INV_PARAM(xbar_data_width_p)
   , parameter int `BSG_INV_PARAM(source_data_width_p) [num_source_p:0]
   , parameter int `BSG_INV_PARAM(sink_data_width_p) [num_sink_p:0]

   , localparam lg_num_source_lp = `BSG_SAFE_CLOG2(num_source_p)
   , localparam lg_num_sink_lp   = `BSG_SAFE_CLOG2(num_sink_p)

   , localparam source_data_width_lp = source_data_width_p[num_source_p]
   , localparam sink_data_width_lp = sink_data_width_p[num_sink_p]

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, xbar)
   )
  (input                                                              clk_i
   , input                                                            reset_i

   , input [num_source_p-1:0][xbar_header_width_lp-1:0]               msg_header_i
   , input [source_data_width_lp-1:0]                                 msg_data_i
   , input [num_source_p-1:0]                                         msg_v_i
   , output logic [num_source_p-1:0]                                  msg_ready_and_o
   , input [num_source_p-1:0]                                         msg_last_i
   , input [num_source_p-1:0][lg_num_sink_lp-1:0]                     msg_dst_i

   , output logic [num_sink_p-1:0][xbar_header_width_lp-1:0]          msg_header_o
   , output logic [sink_data_width_lp-1:0]                            msg_data_o
   , output logic [num_sink_p-1:0]                                    msg_v_o
   , input [num_sink_p-1:0]                                           msg_ready_and_i
   , output logic [num_sink_p-1:0]                                    msg_last_o
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, xbar);
  bp_bedrock_xbar_header_s [num_source_p-1:0] xbar_header_li;
  logic [num_source_p-1:0][xbar_data_width_p-1:0] xbar_data_li;
  logic [num_source_p-1:0] xbar_v_li, xbar_yumi_lo, xbar_last_li;

  bp_bedrock_xbar_header_s [num_sink_p-1:0] xbar_header_lo;
  logic [num_sink_p-1:0][xbar_data_width_p-1:0] xbar_data_lo;
  logic [num_sink_p-1:0] xbar_v_lo, xbar_ready_and_li, xbar_last_lo;

  logic [num_source_p-1:0][lg_num_sink_lp-1:0] xbar_dst_li;
  for (genvar i = 0; i < num_source_p; i++)
    begin : buffer
      localparam dw = source_data_width_p[i+1] - source_data_width_p[i];

      // Optimal buffering strategy depends on data width
      bp_bedrock_xbar_header_s msg_header_li;
      logic [dw-1:0] msg_data_li;
      logic msg_v_li, msg_ready_and_lo, msg_last_li;
      logic [lg_num_sink_lp-1:0] msg_dst_li;
      wire [dw-1:0] msg_data_slice = msg_data_i[source_data_width_p[i+1]-1:source_data_width_p[i]];
      bsg_two_fifo
       #(.width_p(lg_num_sink_lp+1+dw+xbar_header_width_lp))
       in_fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i({msg_dst_i[i], msg_last_i[i], msg_data_slice, msg_header_i[i]})
         ,.v_i(msg_v_i[i])
         ,.ready_o(msg_ready_and_o[i])

         ,.data_o({msg_dst_li, msg_last_li, msg_data_li, msg_header_li})
         ,.v_o(msg_v_li)
         ,.yumi_i(msg_ready_and_lo & msg_v_li)
         );
      assign xbar_dst_li[i] = msg_dst_li;

      bp_me_stream_gearbox
       #(.bp_params_p(bp_params_p)
         ,.in_data_width_p(dw)
         ,.out_data_width_p(xbar_data_width_p)
         ,.payload_width_p($bits(xbar_header_li[i].payload))
         ,.payload_mask_p(payload_mask_p)
         )
       source_gearbox
        (.clk_i(clk_i)
         ,.reset_i(reset_i)
         ,.msg_header_i(msg_header_li)
         ,.msg_data_i(msg_data_li)
         ,.msg_v_i(msg_v_li)
         ,.msg_ready_and_o(msg_ready_and_lo)
         ,.msg_last_i(msg_last_li)

         ,.msg_header_o(xbar_header_li[i])
         ,.msg_data_o(xbar_data_li[i])
         ,.msg_v_o(xbar_v_li[i])
         ,.msg_ready_and_i(xbar_yumi_lo[i])
         ,.msg_last_o(xbar_last_li[i])
         );
    end

  logic [num_sink_p-1:0] xbar_unlock_li;
  logic [num_sink_p-1:0][num_source_p-1:0] grants_oi_one_hot_lo;
  bsg_crossbar_control_locking_o_by_i
   #(.i_els_p(num_source_p), .o_els_p(num_sink_p))
   cbc
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.valid_i(xbar_v_li)
     ,.sel_io_i(xbar_dst_li)
     ,.yumi_o(xbar_yumi_lo)

     ,.ready_and_i(xbar_ready_and_li)
     ,.valid_o(xbar_v_lo)
     ,.unlock_i(xbar_unlock_li)
     ,.grants_oi_one_hot_o(grants_oi_one_hot_lo)
     );

  logic [num_source_p-1:0][xbar_header_width_lp+xbar_data_width_p+1-1:0] source_combine;
  logic [num_sink_p-1:0][xbar_header_width_lp+xbar_data_width_p+1-1:0] sink_combine;
  for (genvar i = 0; i < num_source_p; i++)
    begin : source_comb
      assign source_combine[i] = {xbar_v_li[i] & xbar_last_li[i], xbar_header_li[i], xbar_data_li[i]};
    end
  for (genvar i = 0; i < num_sink_p; i++)
    begin : sink_comb
      localparam dw = sink_data_width_p[i+1] - sink_data_width_p[i];

      bp_me_stream_gearbox
       #(.bp_params_p(bp_params_p)
         ,.in_data_width_p(xbar_data_width_p)
         ,.out_data_width_p(dw)
         ,.payload_width_p($bits(xbar_header_lo[i].payload))
         ,.payload_mask_p(payload_mask_p)
         )
       sink_gearbox
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.msg_header_i(xbar_header_lo[i])
         ,.msg_data_i(xbar_data_lo[i])
         ,.msg_v_i(xbar_v_lo[i])
         ,.msg_ready_and_o(xbar_ready_and_li[i])
         ,.msg_last_i(xbar_last_lo[i])

         ,.msg_header_o(msg_header_o[i])
         ,.msg_data_o(msg_data_o[sink_data_width_p[i+1]-1:sink_data_width_p[i]])
         ,.msg_v_o(msg_v_o[i])
         ,.msg_ready_and_i(msg_ready_and_i[i])
         ,.msg_last_o(msg_last_o[i])
         );

      assign {xbar_last_lo[i], xbar_header_lo[i], xbar_data_lo[i]} = sink_combine[i];
      assign xbar_unlock_li[i] = xbar_ready_and_li[i] & xbar_v_lo[i] & xbar_last_lo[i];
    end

  bsg_crossbar_o_by_i
   #(.i_els_p(num_source_p), .o_els_p(num_sink_p), .width_p(1+xbar_header_width_lp+xbar_data_width_p))
   cb
    (.i(source_combine)
     ,.sel_oi_one_hot_i(grants_oi_one_hot_lo)
     ,.o(sink_combine)
     );

endmodule

`BSG_ABSTRACT_MODULE(bp_me_xbar_stream)

