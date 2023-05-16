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

   , parameter `BSG_INV_PARAM(block_width_p)
   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(payload_width_p)
   , parameter `BSG_INV_PARAM(num_source_p)
   , parameter `BSG_INV_PARAM(num_sink_p)
   , parameter payload_mask_p = 0
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, xbar)

   , localparam lg_num_source_lp = `BSG_SAFE_CLOG2(num_source_p)
   , localparam lg_num_sink_lp   = `BSG_SAFE_CLOG2(num_sink_p)
   , localparam words_lp         = block_width_p / data_width_p
   )
  (input                                                              clk_i
   , input                                                            reset_i

   , input [num_source_p-1:0][xbar_header_width_lp-1:0]               msg_header_i
   , input [num_source_p-1:0][data_width_p-1:0]                       msg_data_i
   , input [num_source_p-1:0]                                         msg_v_i
   , output logic [num_source_p-1:0]                                  msg_ready_and_o
   , input [num_source_p-1:0][lg_num_sink_lp-1:0]                     msg_dst_i

   , output logic [num_sink_p-1:0][xbar_header_width_lp-1:0]          msg_header_o
   , output logic [num_sink_p-1:0][data_width_p-1:0]                  msg_data_o
   , output logic [num_sink_p-1:0]                                    msg_v_o
   , input [num_sink_p-1:0]                                           msg_ready_and_i
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, xbar);
   bp_bedrock_xbar_header_s [num_source_p-1:0] msg_header_li;
   logic [num_source_p-1:0][data_width_p-1:0] msg_data_li;
   logic [num_source_p-1:0] msg_v_li, msg_yumi_lo;
   logic [num_source_p-1:0][lg_num_sink_lp-1:0] msg_dst_li;

  for (genvar i = 0; i < num_source_p; i++)
    begin : buffer
      bsg_two_fifo
       #(.width_p(lg_num_sink_lp+data_width_p+xbar_header_width_lp))
       in_fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i({msg_dst_i[i], msg_data_i[i], msg_header_i[i]})
         ,.v_i(msg_v_i[i])
         ,.ready_o(msg_ready_and_o[i])

         ,.data_o({msg_dst_li[i], msg_data_li[i], msg_header_li[i]})
         ,.v_o(msg_v_li[i])
         ,.yumi_i(msg_yumi_lo[i])
         );
    end

  logic [num_sink_p-1:0] msg_unlock_li;
  logic [num_sink_p-1:0][num_source_p-1:0] grants_oi_one_hot_lo;
  bsg_crossbar_control_locking_o_by_i
   #(.i_els_p(num_source_p), .o_els_p(num_sink_p))
   cbc
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.valid_i(msg_v_li)
     ,.sel_io_i(msg_dst_li)
     ,.yumi_o(msg_yumi_lo)

     ,.ready_and_i(msg_ready_and_i)
     ,.valid_o(msg_v_o)
     ,.unlock_i(msg_unlock_li)
     ,.grants_oi_one_hot_o(grants_oi_one_hot_lo)
     );

  logic [num_source_p-1:0][xbar_header_width_lp+data_width_p-1:0] source_combine;
  logic [num_sink_p-1:0][xbar_header_width_lp+data_width_p-1:0] sink_combine;
  for (genvar i = 0; i < num_source_p; i++)
    begin : source_comb
      assign source_combine[i] = {msg_header_li[i], msg_data_li[i]};
    end
  for (genvar i = 0; i < num_sink_p; i++)
    begin : sink_comb
      logic msg_last_lo;
      bp_me_stream_pump_control
       #(.bp_params_p(bp_params_p)
         ,.max_val_p(words_lp-1)
         ,.fsm_stream_mask_p(payload_mask_p)
         ,.data_width_p(data_width_p)
         ,.payload_width_p(payload_width_p)
         )
       pump_control
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.msg_header_i(msg_header_o[i])
         ,.en_i(msg_ready_and_i[i] & msg_v_o[i])

         ,.wrap_o()
         ,.first_o()
         ,.last_o(msg_last_lo)
         );

      assign {msg_header_o[i], msg_data_o[i]} = sink_combine[i];
      assign msg_unlock_li[i] = msg_ready_and_i[i] & msg_v_o[i] & msg_last_lo;
    end

  bsg_crossbar_o_by_i
   #(.i_els_p(num_source_p), .o_els_p(num_sink_p), .width_p(xbar_header_width_lp+data_width_p))
   cb
    (.i(source_combine)
     ,.sel_oi_one_hot_i(grants_oi_one_hot_lo)
     ,.o(sink_combine)
     );

endmodule

`BSG_ABSTRACT_MODULE(bp_me_xbar_stream)

