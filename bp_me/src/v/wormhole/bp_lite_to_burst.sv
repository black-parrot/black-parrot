
module bp_lite_to_burst
 import bp_common_pkg::*;
 import bp_common_aviary_pkg::*;
 import bp_me_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   , parameter in_data_width_p  = "inv"
   , parameter out_data_width_p = "inv"
   , parameter payload_width_p  = "inv"

   // Bitmask which determines which message types have a data payload
   // Constructed as (1 << e_payload_msg1 | 1 << e_payload_msg2)
   , parameter int payload_mask_p = 0

   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in)
   `declare_bp_bedrock_if_widths(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out)
   )
  (input                                            clk_i
   , input                                          reset_i

   // Master BP Lite
   // ready-valid-and
   , input [in_msg_width_lp-1:0]                    in_msg_i
   , input                                          in_msg_v_i
   , output logic                                   in_msg_ready_and_o

   // Client BP Burst
   // ready-valid-and
   , output logic [out_msg_header_width_lp-1:0]     out_msg_header_o
   , output logic                                   out_msg_header_v_o
   , input logic                                    out_msg_header_ready_and_i

   // ready-valid-and
   , output logic [out_data_width_p-1:0]            out_msg_data_o
   , output logic                                   out_msg_data_v_o
   , input                                          out_msg_data_ready_and_i
   );

  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, in_data_width_p, lce_id_width_p, lce_assoc_p, in);
  `declare_bp_bedrock_if(paddr_width_p, payload_width_p, out_data_width_p, lce_id_width_p, lce_assoc_p, out);
  bp_bedrock_in_msg_s in_msg_cast_i;
  assign in_msg_cast_i = in_msg_i;

  localparam in_data_bytes_lp = in_data_width_p/8;
  localparam out_data_bytes_lp = out_data_width_p/8;
  localparam burst_words_lp = in_data_width_p/out_data_width_p;
  localparam burst_offset_width_lp = `BSG_SAFE_CLOG2(out_data_bytes_lp);

  // Hold the header for burst
  bp_bedrock_in_msg_header_s header_lo;
  bsg_dff_en_bypass
   #(.width_p($bits(bp_bedrock_in_msg_header_s)))
   header_reg
    (.clk_i(clk_i)
    ,.en_i(in_msg_ready_and_o & in_msg_v_i)
    ,.data_i(in_msg_cast_i.header)
    ,.data_o(header_lo) 
    );
  
  // header valid logic
  logic header_v_r, header_clear;
  bsg_dff_reset_set_clear
   #(.width_p(1)
   ,.clear_over_set_p(1))
    header_v_reg
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.set_i(in_msg_ready_and_o & in_msg_v_i)
    ,.clear_i(header_clear)
    ,.data_o(header_v_r)
    );
  assign out_msg_header_o = header_lo;
  assign out_msg_header_v_o = in_msg_v_i | header_v_r;
  assign header_clear = out_msg_header_ready_and_i & out_msg_header_v_o; // clear when the header is acked

  wire has_data = payload_mask_p[header_lo.msg_type];
  localparam data_len_width_lp = `BSG_SAFE_CLOG2(burst_words_lp);
  wire [data_len_width_lp-1:0] num_burst_cmds = `BSG_MAX(1, (1'b1 << header_lo.size) / out_data_bytes_lp);

  logic data_bursting_r, data_burst_clear, data_ready_and_lo;
  // Hold the data for burst
  logic [in_data_width_p-1:0] data_lo;
  bsg_dff_en_bypass
   #(.width_p(in_data_width_p))
   data_reg
    (.clk_i(clk_i)
    ,.en_i(in_msg_ready_and_o & in_msg_v_i)
    ,.data_i(in_msg_cast_i.data)
    ,.data_o(data_lo)
    );

  bsg_parallel_in_serial_out_passthrough_dynamic
   #(.width_p(out_data_width_p), .max_els_p(burst_words_lp))
   piso_passthrough
    (.clk_i(clk_i)
    ,.reset_i(reset_i)

    ,.ready_and_o(data_ready_and_lo)
    ,.v_i((in_msg_v_i & has_data) | data_bursting_r)
    ,.data_i(data_lo)
    ,.len_i(num_burst_cmds - 1'b1)

    ,.data_o(out_msg_data_o)
    ,.v_o(out_msg_data_v_o)
    ,.ready_and_i(out_msg_data_ready_and_i)
    ,.first_o(/* unused */)  
    );

  // indicates pending burst data & keep v_i high during burst
  bsg_dff_reset_set_clear
   #(.width_p(1)
   ,.clear_over_set_p(1))
    data_bursting_reg
    (.clk_i(clk_i)
    ,.reset_i(reset_i)
    ,.set_i(in_msg_ready_and_o & in_msg_v_i & has_data)
    ,.clear_i(data_burst_clear)
    ,.data_o(data_bursting_r)
    );

  assign data_burst_clear = data_ready_and_lo;

  // Accept no new lite pkt with: 
  // 1. pending header in the register
  // 2. pending burst data 
  assign in_msg_ready_and_o = ~header_v_r & ~data_bursting_r;

  //synopsys translate_off
  initial
    begin
      assert (in_data_width_p >= out_data_width_p)
        else $error("Master data cannot be smaller than client");
      assert (in_data_width_p % out_data_width_p == 0)
        else $error("Master data must be a multiple of client data");
    end

  always_ff @(negedge clk_i)
    begin
      //if (in_msg_ready_and_o & in_msg_v_i)
      //  $display("[%t] Msg received: %p", $time, in_msg_cast_i);

      //if (out_msg_header_ready_and_i & out_msg_header_v_o)
      //  $display("[%t] Stream sent: %p %x CNT: %x", $time, msg_header_cast_o, out_msg_data_o, num_burst_cmds);
    end
  //synopsys translate_on

endmodule

