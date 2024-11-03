/**
 *
 * Name:
 *   bp_cce_hybrid_pending_queue.sv
 *
 * Description:
 *   This module holds requests that are blocked due to an existing outstanding request.
 *
 *   The buffer is full if lce_req_ready_and_o is 1'b0
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_pending_queue
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter buffer_els_p     = 2

    // interface width
    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
  )
  (input                                            clk_i
   , input                                          reset_i

   // LCE Request in
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input [bedrock_fill_width_p-1:0]               lce_req_data_i
   , input                                          lce_req_v_i
   , input                                          lce_req_last_i
   , output logic                                   lce_req_ready_and_o

   // LCE request out
   , output logic [lce_req_header_width_lp-1:0]     lce_req_header_o
   , output logic [bedrock_fill_width_p-1:0]        lce_req_data_o
   , output logic                                   lce_req_v_o
   , output logic                                   lce_req_last_o
   , input                                          lce_req_yumi_i
   );

  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_o(bp_bedrock_lce_req_header_s, lce_req_header);

  // LCE Request Header Buffer
  bsg_fifo_1r1w_small
    #(.width_p(lce_req_header_width_lp+bedrock_fill_width_p+1)
      ,.els_p(buffer_els_p)
      ,.ready_THEN_valid_p(0)
      )
    header_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // input
      ,.v_i(lce_req_v_i)
      ,.ready_param_o(lce_req_ready_and_o)
      ,.data_i({lce_req_last_i, lce_req_data_i, lce_req_header_cast_i})
      // output
      ,.v_o(lce_req_v_o)
      ,.yumi_i(lce_req_yumi_i)
      ,.data_o({lce_req_last_o, lce_req_data_o, lce_req_header_cast_o})
      );

  /*
  // Combinational Logic
  always_comb begin
  end

  // Sequential Logic
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
    end else begin
    end
  end
  */

endmodule
