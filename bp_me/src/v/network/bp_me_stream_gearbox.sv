
`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_stream_gearbox
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(buffered_p)
   , parameter `BSG_INV_PARAM(in_data_width_p)
   , parameter `BSG_INV_PARAM(out_data_width_p)
   , parameter `BSG_INV_PARAM(payload_width_p)
   , parameter `BSG_INV_PARAM(stream_mask_p)
   `declare_bp_bedrock_generic_if_width(paddr_width_p, payload_width_p, xce)
   )
  (input                                            clk_i
   , input                                          reset_i

   , input [xce_header_width_lp-1:0]                msg_header_i
   , input [in_data_width_p-1:0]                    msg_data_i
   , input                                          msg_v_i
   , output logic                                   msg_ready_and_o

   , output logic [xce_header_width_lp-1:0]         msg_header_o
   , output logic [out_data_width_p-1:0]            msg_data_o
   , output logic                                   msg_v_o
   // Helpful when buffered_p is set
   , input                                          msg_ready_param_i
   );

  `declare_bp_bedrock_generic_if(paddr_width_p, payload_width_p, xce);
  `bp_cast_i(bp_bedrock_xce_header_s, msg_header);
  `bp_cast_o(bp_bedrock_xce_header_s, msg_header);

  bp_bedrock_xce_header_s msg_header_li;
  logic [in_data_width_p-1:0] msg_data_li;
  logic msg_v_li, msg_ready_and_lo;

  if (buffered_p)
    begin : buffer
      bsg_two_fifo
       #(.width_p($bits(bp_bedrock_xce_header_s)+in_data_width_p))
       fifo
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i({msg_header_cast_i, msg_data_i})
         ,.v_i(msg_v_i)
         ,.ready_param_o(msg_ready_and_o)

         ,.data_o({msg_header_li, msg_data_li})
         ,.v_o(msg_v_li)
         ,.yumi_i(msg_ready_and_lo & msg_v_li)
         );
    end
  else
    begin : no_buffer
      assign msg_header_li = msg_header_cast_i;
      assign msg_data_li = msg_data_i;
      assign msg_v_li = msg_v_i;
      assign msg_ready_and_o = msg_ready_and_lo;
    end

  // Header passes right through
  assign msg_header_cast_o = msg_header_li;

  if (in_data_width_p < out_data_width_p)
    begin : widen
      localparam in_max_len_lp = `BSG_CDIV(8*(1 << e_bedrock_msg_size_128), in_data_width_p);
      logic [in_max_len_lp-1:0] in_len_lo;
      bp_bedrock_size_to_len
       #(.beat_width_p(in_data_width_p), .len_width_p(in_max_len_lp))
       in_s2l
        (.size_i(msg_header_li.size), .len_o(in_len_lo));

      localparam sipop_els_lp = out_data_width_p / in_data_width_p;
      wire full_sipop = in_len_lo >= sipop_els_lp;
      wire empty_sipop = !stream_mask_p[msg_header_li.msg_type];
      wire [`BSG_SAFE_CLOG2(sipop_els_lp)-1:0] sipop_len_li =
        empty_sipop ? '0 : full_sipop ? '1 : in_len_lo;
      bsg_serial_in_parallel_out_passthrough_dynamic
       #(.width_p(in_data_width_p), .els_p(sipop_els_lp))
       sipop
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(msg_data_li)
         ,.v_i(msg_v_li)
         ,.len_i(sipop_len_li)
         ,.ready_and_o(msg_ready_and_lo)

         ,.data_o(msg_data_o)
         ,.v_o(msg_v_o)
         ,.ready_and_i(msg_ready_param_i)
         );
    end
  else if (in_data_width_p > out_data_width_p)
    begin : narrow
      localparam out_max_len_lp = `BSG_CDIV(8*(1 << e_bedrock_msg_size_128), out_data_width_p);
      logic [out_max_len_lp-1:0] out_len_lo;
      bp_bedrock_size_to_len
       #(.beat_width_p(out_data_width_p), .len_width_p(out_max_len_lp))
       out_s2l
        (.size_i(msg_header_li.size), .len_o(out_len_lo));

      localparam pisop_els_lp = in_data_width_p / out_data_width_p;
      wire full_pisop = out_len_lo >= pisop_els_lp;
      wire empty_pisop = !stream_mask_p[msg_header_li.msg_type];
      wire [`BSG_SAFE_CLOG2(pisop_els_lp)-1:0] pisop_len_li =
        empty_pisop ? '0 : full_pisop ? '1 : out_len_lo;
      bsg_parallel_in_serial_out_passthrough_dynamic
       #(.width_p(out_data_width_p), .els_p(pisop_els_lp))
       pisop
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.data_i(msg_data_li)
         ,.v_i(msg_v_li)
         ,.len_i(pisop_len_li)
         ,.ready_and_o(msg_ready_and_lo)

         ,.data_o(msg_data_o)
         ,.v_o(msg_v_o)
         ,.ready_and_i(msg_ready_param_i)
         );
    end
  else
    begin
      assign msg_data_o = msg_data_li;
      assign msg_v_o = msg_v_li;
      assign msg_ready_and_lo = msg_ready_param_i;
    end

endmodule

`BSG_ABSTRACT_MODULE(bp_me_stream_gearbox)

