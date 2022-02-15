/**
 *
 * Name:
 *   bp_me_stream_gearbox.sv
 *
 * Description:
 *   This module changes the width of a bedrock stream. Ratio must be POT between the two.
 *   TODO: short-circuit if data size < bus size
 *   TODO: bus_bus_pack
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_me_stream_gearbox
 import bp_common_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter `BSG_INV_PARAM(in_data_width_p)
   , parameter `BSG_INV_PARAM(out_data_width_p)
   , parameter `BSG_INV_PARAM(payload_width_p)
   , parameter `BSG_INV_PARAM(payload_mask_p)

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, in)
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, out)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Input BedRock Stream
   , input [in_header_width_lp-1:0]                 msg_header_i
   , input [in_data_width_p-1:0]                    msg_data_i
   , input                                          msg_v_i
   , output logic                                   msg_ready_and_o
   , input                                          msg_last_i

   // Output BedRock Stream
   , output logic [out_header_width_lp-1:0]         msg_header_o
   , output logic [out_data_width_p-1:0]            msg_data_o
   , output logic                                   msg_v_o
   , input                                          msg_ready_and_i
   , output logic                                   msg_last_o
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, lce_id_width_p, lce_assoc_p, out);
  `bp_cast_i(bp_bedrock_in_header_s, msg_header);
  `bp_cast_o(bp_bedrock_out_header_s, msg_header);

  localparam narrow_ratio_lp = in_data_width_p / out_data_width_p;
  localparam wide_ratio_lp = out_data_width_p / in_data_width_p;

  // We need to replicate for the case that out_width > in_width and msg_length < out_width
  // So this is a bit overkill, but should work
  localparam data_bytes_lp = (out_data_width_p>>3);
  localparam data_byte_offset_width_lp = `BSG_SAFE_CLOG2(data_bytes_lp);
  localparam bus_pack_size_width_lp = `BSG_WIDTH(data_byte_offset_width_lp);

  wire has_data =
    payload_mask_p[msg_header_cast_i.msg_type] && (msg_header_cast_i.size > `BSG_SAFE_CLOG2(data_bytes_lp));

  if (narrow_ratio_lp == 1)
    begin : passthrough
      assign msg_header_cast_o = msg_header_i;
      assign msg_data_o = msg_data_i;
      assign msg_v_o = msg_v_i;
      assign msg_last_o = msg_last_i;
      assign msg_ready_and_o = msg_ready_and_i;
    end
  else if (narrow_ratio_lp >= 1)
    begin : narrow
      localparam out_words_lp = narrow_ratio_lp;
      localparam cnt_width_lp = `BSG_SAFE_CLOG2(out_words_lp);
      localparam offset_width_lp = `BSG_SAFE_CLOG2(out_data_width_p>>3);

      logic msg_data_v_lo;
      bsg_parallel_in_serial_out_passthrough
       #(.width_p(out_data_width_p), .els_p(narrow_ratio_lp))
       pisop
        (.clk_i(clk_i)
         ,.reset_i(reset_i | (msg_ready_and_i & msg_v_o & msg_last_o))

         ,.data_i(msg_data_i)
         ,.v_i(msg_v_i)
         ,.ready_and_o()

         ,.data_o(msg_data_o)
         ,.v_o(msg_data_v_lo)
         ,.ready_and_i(msg_ready_and_i)
         );
      assign msg_ready_and_o = msg_ready_and_i & msg_v_o & msg_last_o;

      logic [cnt_width_lp-1:0] cnt;
      bsg_counter_clear_up
       #(.max_val_p(out_words_lp-1), .init_val_p('0), .disable_overflow_warning_p(1))
       counter
        (.clk_i(clk_i)
         ,.reset_i(reset_i)

         ,.clear_i(1'b0)
         ,.up_i(has_data & msg_v_o & msg_ready_and_i)
         ,.count_o(cnt)
         );
      assign msg_v_o = msg_v_i & (~has_data | msg_data_v_lo);
      assign msg_last_o = msg_last_i & (~has_data | (msg_data_v_lo && cnt == out_words_lp-1));

      wire [cnt_width_lp-1:0] wrap = cnt + msg_header_cast_i.addr[offset_width_lp+:cnt_width_lp];
      always_comb
        begin
          msg_header_cast_o = msg_header_cast_i;
          msg_header_cast_o.addr = {msg_header_cast_i.addr[paddr_width_p-1:offset_width_lp+cnt_width_lp]
                                    ,cnt_width_lp'(wrap)
                                    ,msg_header_cast_i.addr[0+:offset_width_lp]
                                    };
        end
    end
  else
    begin : wide
      localparam in_words_lp = wide_ratio_lp;
      localparam cnt_width_lp = `BSG_SAFE_CLOG2(in_words_lp);
      localparam offset_width_lp = `BSG_SAFE_CLOG2(in_data_width_p>>3);

      logic [out_data_width_p-1:0] msg_data_lo;
      logic msg_data_v_lo;
      bsg_serial_in_parallel_out_passthrough
       #(.width_p(in_data_width_p), .els_p(wide_ratio_lp))
       sisop
        (.clk_i(clk_i)
         ,.reset_i(reset_i | (msg_v_o & msg_ready_and_i & msg_last_o))

         ,.data_i(msg_data_i)
         ,.v_i(msg_v_i)
         ,.ready_and_o()

         ,.data_o(msg_data_lo)
         ,.v_o(msg_data_v_lo)
         ,.ready_and_i(msg_ready_and_i)
         );
      assign msg_ready_and_o = msg_ready_and_i;

      wire [bus_pack_size_width_lp-1:0] msg_size_li = ((1 << msg_header_cast_i.size) > data_bytes_lp)
        ? bus_pack_size_width_lp'(data_byte_offset_width_lp)
        : msg_header_cast_i.size[0+:bus_pack_size_width_lp];
      bsg_bus_pack
       #(.in_width_p(out_data_width_p))
       out_bus_pack
        (.data_i(msg_data_lo)
         ,.sel_i('0)
         ,.size_i(msg_size_li)
         ,.data_o(msg_data_o)
         );

      assign msg_v_o = msg_v_i & (~has_data | msg_data_v_lo);
      assign msg_last_o = msg_last_i & (~has_data | msg_data_v_lo);

      wire [cnt_width_lp-1:0] wrap = '0;
      always_comb
        begin
          msg_header_cast_o = msg_header_cast_i;
          msg_header_cast_o.addr = {msg_header_cast_i.addr[paddr_width_p-1:offset_width_lp+cnt_width_lp]
                                    ,cnt_width_lp'(wrap)
                                    ,msg_header_cast_i.addr[0+:offset_width_lp]
                                    };
        end
    end


endmodule

`BSG_ABSTRACT_MODULE(bp_me_stream_gearbox)
