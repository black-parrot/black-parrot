/**
 *
 * Name:
 *   bp_me_xbar_burst.sv
 *
 * Description:
 *   This xbar arbitrates BedRock Burst messages between N sources and M sinks.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_xbar_burst
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(data_width_p)
   , parameter `BSG_INV_PARAM(payload_width_p)
   , parameter `BSG_INV_PARAM(num_source_p)
   , parameter `BSG_INV_PARAM(num_sink_p)
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, xbar)

   , localparam lg_num_source_lp = `BSG_SAFE_CLOG2(num_source_p)
   , localparam lg_num_sink_lp   = `BSG_SAFE_CLOG2(num_sink_p)
   )
  (input                                                              clk_i
   , input                                                            reset_i

   , input [num_source_p-1:0][xbar_header_width_lp-1:0]               msg_header_i
   , input [num_source_p-1:0]                                         msg_header_v_i
   , output logic [num_source_p-1:0]                                  msg_header_ready_and_o
   , input [num_source_p-1:0]                                         msg_has_data_i
   , input [num_source_p-1:0][data_width_p-1:0]                       msg_data_i
   , input [num_source_p-1:0]                                         msg_data_v_i
   , output logic [num_source_p-1:0]                                  msg_data_ready_and_o
   , input [num_source_p-1:0]                                         msg_last_i
   , input [num_source_p-1:0][lg_num_sink_lp-1:0]                     msg_dst_i

   , output logic [num_sink_p-1:0][xbar_header_width_lp-1:0]          msg_header_o
   , output logic [num_sink_p-1:0]                                    msg_header_v_o
   , input [num_sink_p-1:0]                                           msg_header_ready_and_i
   , output logic [num_sink_p-1:0]                                    msg_has_data_o
   , output logic [num_sink_p-1:0][data_width_p-1:0]                  msg_data_o
   , output logic [num_sink_p-1:0]                                    msg_data_v_o
   , input [num_sink_p-1:0]                                           msg_data_ready_and_i
   , output logic [num_sink_p-1:0]                                    msg_last_o
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, xbar);
  bp_bedrock_xbar_header_s [num_source_p-1:0] msg_header_li;
  logic [num_source_p-1:0][lg_num_sink_lp-1:0] msg_header_dst_li;
  logic [num_source_p-1:0] msg_header_v_li, msg_header_yumi_lo, msg_has_data_li;
  logic [num_source_p-1:0][data_width_p-1:0] msg_data_li;
  logic [num_source_p-1:0][lg_num_sink_lp-1:0] msg_data_dst_li;
  logic [num_source_p-1:0] msg_data_v_li, msg_data_yumi_lo, msg_last_li;

  logic [num_source_p-1:0] header_cb_valid_li, header_cb_yumi_lo;
  logic [num_source_p-1:0][lg_num_sink_lp-1:0] header_cb_sel_li;
  logic [num_source_p-1:0] data_cb_valid_li, data_cb_yumi_lo;
  logic [num_source_p-1:0][lg_num_sink_lp-1:0] data_cb_sel_li;

  logic [num_source_p-1:0] msg_data_dst_v_li, msg_data_dst_yumi_lo;

  for (genvar i = 0; i < num_source_p; i++)
    begin : buffer
      logic header_fifo_ready_lo, header_fifo_v_li;
      bsg_two_fifo
       #(.width_p(lg_num_sink_lp+1+xbar_header_width_lp))
       header_fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)
 
         ,.data_i({msg_dst_i[i], msg_has_data_i[i], msg_header_i[i]})
         ,.v_i(header_fifo_v_li)
         ,.ready_o(header_fifo_ready_lo)
 
         ,.data_o({msg_header_dst_li[i], msg_has_data_li[i], msg_header_li[i]})
         ,.v_o(msg_header_v_li[i])
         ,.yumi_i(msg_header_yumi_lo[i])
         );
      assign header_fifo_v_li = msg_header_ready_and_o[i] & msg_header_v_i[i];

      logic data_dst_fifo_ready_lo, data_dst_fifo_v_li;
      bsg_two_fifo
       #(.width_p(lg_num_sink_lp))
       data_dst_fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(msg_dst_i[i])
         ,.v_i(data_dst_fifo_v_li)
         ,.ready_o(data_dst_fifo_ready_lo)

         ,.data_o(msg_data_dst_li[i])
         ,.v_o(msg_data_dst_v_li[i])
         ,.yumi_i(msg_data_dst_yumi_lo[i])
         );
      assign data_dst_fifo_v_li = header_fifo_v_li & msg_has_data_i[i];

      assign msg_header_ready_and_o[i] = header_fifo_ready_lo & data_dst_fifo_ready_lo;

      bsg_two_fifo
       #(.width_p(1+data_width_p))
       data_fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i({msg_last_i[i], msg_data_i[i]})
         ,.v_i(msg_data_v_i[i])
         ,.ready_o(msg_data_ready_and_o[i])

         ,.data_o({msg_last_li[i], msg_data_li[i]})
         ,.v_o(msg_data_v_li[i])
         ,.yumi_i(msg_data_yumi_lo[i])
         );
    end

  logic [num_sink_p-1:0] header_cb_ready_and_li, header_cb_valid_lo;
  logic [num_sink_p-1:0][num_source_p-1:0] header_grants_oi_one_hot_lo;
  bsg_crossbar_control_basic_o_by_i
   #(.i_els_p(num_source_p), .o_els_p(num_sink_p))
   header_cbc
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.valid_i(header_cb_valid_li)
     ,.sel_io_i(header_cb_sel_li)
     ,.yumi_o(header_cb_yumi_lo)

     ,.ready_and_i(header_cb_ready_and_li)
     ,.valid_o(header_cb_valid_lo)
     ,.grants_oi_one_hot_o(header_grants_oi_one_hot_lo)
     );

  logic [num_source_p-1:0][xbar_header_width_lp+1-1:0] header_source_combine;
  logic [num_sink_p-1:0][xbar_header_width_lp+1-1:0] header_sink_combine;
  bsg_crossbar_o_by_i
   #(.i_els_p(num_source_p), .o_els_p(num_sink_p), .width_p(1+xbar_header_width_lp))
   header_cb
    (.i(header_source_combine)
     ,.sel_oi_one_hot_i(header_grants_oi_one_hot_lo)
     ,.o(header_sink_combine)
     );

  logic [num_sink_p-1:0] data_cb_ready_and_li, data_cb_valid_lo;
  logic [num_sink_p-1:0][num_source_p-1:0] data_grants_oi_one_hot_lo;
  logic [num_sink_p-1:0] data_cb_unlock_li;
  bsg_crossbar_control_locking_o_by_i
   #(.i_els_p(num_source_p), .o_els_p(num_sink_p))
   data_cbc
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.valid_i(data_cb_valid_li)
     ,.sel_io_i(data_cb_sel_li)
     ,.yumi_o(data_cb_yumi_lo)

     ,.unlock_i(data_cb_unlock_li)
     ,.ready_and_i(data_cb_ready_and_li)
     ,.valid_o(data_cb_valid_lo)
     ,.grants_oi_one_hot_o(data_grants_oi_one_hot_lo)
     );

  logic [num_sink_p-1:0][data_width_p+1-1:0] data_sink_combine;
  logic [num_source_p-1:0][data_width_p+1-1:0] data_source_combine;
  bsg_crossbar_o_by_i
   #(.i_els_p(num_source_p), .o_els_p(num_sink_p), .width_p(1+data_width_p))
   data_cb
    (.i(data_source_combine)
     ,.sel_oi_one_hot_i(data_grants_oi_one_hot_lo)
     ,.o(data_sink_combine)
     );

  for (genvar i = 0; i < num_source_p; i++)
    begin : source_comb
      assign header_cb_valid_li[i] = msg_header_v_li[i];
      assign header_cb_sel_li[i] = msg_header_dst_li[i];
      assign msg_header_yumi_lo[i] = header_cb_yumi_lo[i];
      assign header_source_combine[i] = {msg_has_data_li[i], msg_header_li[i]};

      assign data_cb_valid_li[i] = msg_data_v_li[i] & msg_data_dst_v_li[i];
      assign data_cb_sel_li[i] = msg_data_dst_li[i];
      assign msg_data_yumi_lo[i] = data_cb_yumi_lo[i];
      assign data_source_combine[i] = {msg_last_li[i], msg_data_li[i]};

      assign msg_data_dst_yumi_lo[i] = msg_data_yumi_lo[i] & msg_last_li[i] & msg_data_dst_v_li[i];
    end

  for (genvar i = 0; i < num_sink_p; i++)
    begin : sink_comb
      assign msg_header_v_o[i] = header_cb_valid_lo[i];
      assign header_cb_ready_and_li[i] =  msg_header_ready_and_i[i];

      assign msg_data_v_o[i] = data_cb_valid_lo[i];
      assign data_cb_ready_and_li[i] = msg_data_ready_and_i[i];
      assign data_cb_unlock_li[i] = msg_data_ready_and_i[i] & msg_data_v_o[i] & msg_last_o[i];

      assign {msg_has_data_o[i], msg_header_o[i]} = header_sink_combine[i];
      assign {msg_last_o[i], msg_data_o[i]} = data_sink_combine[i];
    end

endmodule

