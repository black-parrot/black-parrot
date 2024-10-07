/**
 *
 * Name:
 *   bp_cce_hybrid_prog_pipe.sv
 *
 * Description:
 *   Programmable pipeline that is hooked to coherent request pipeline
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_prog_pipe
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter lce_data_width_p           = dword_width_gp
    , parameter header_fifo_els_p          = 2

    // interface widths
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
  )
  (input                                            clk_i
   , input                                          reset_i

   // control
   , input bp_cce_mode_e                            cce_mode_i
   , input [cce_id_width_p-1:0]                     cce_id_i
   , output logic                                   empty_o

   // LCE request header
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input                                          lce_req_header_v_i
   , output logic                                   lce_req_header_ready_and_o

   // response to coherent pipeline
   , output logic                                   prog_v_o
   , input                                          prog_yumi_i
   , output logic                                   prog_status_o // 1 = okay, 0 = squash
   );

  // Define structure variables for output queues
  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);
  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);

  // Header Buffer
  logic lce_req_header_v_li, lce_req_header_yumi_lo, lce_req_has_data_li;
  bp_bedrock_lce_req_header_s  lce_req_header_li;
  bsg_fifo_1r1w_small
    #(.width_p(lce_req_header_width_lp)
      ,.els_p(header_fifo_els_p)
      )
    header_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // input
      ,.v_i(lce_req_header_v_i)
      ,.ready_o(lce_req_header_ready_and_o)
      ,.data_i(lce_req_header_cast_i)
      // output
      ,.v_o(lce_req_header_v_li)
      ,.yumi_i(lce_req_header_yumi_lo)
      ,.data_o(lce_req_header_li)
      );

  typedef enum logic [4:0] {
    e_reset
    ,e_ready
    ,e_send_status
    ,e_error
  } state_e;

  state_e state_r, state_n;

  always_comb begin
    empty_o = 1'b1;

    state_n = state_r;

    // LCE request
    lce_req_header_yumi_lo = '0;

    prog_v_o = 1'b0;
    prog_status_o = 1'b1;

    case (state_r)
      e_reset: begin
        state_n = e_ready;
      end // e_reset

      e_ready: begin
        lce_req_header_yumi_lo = lce_req_header_v_li;
        state_n = (lce_req_header_yumi_lo) ? e_send_status : state_r;
      end // e_ready

      e_send_status: begin
        prog_v_o = 1'b1;
        prog_status_o = 1'b1;
        state_n = (prog_yumi_i) ? e_ready : state_r;
      end // e_send_status

      e_error: begin
        state_n = e_error;
      end // e_error

      default: begin
        // use defaults above
      end

    endcase
  end // always_comb

  // Sequential Logic
  always_ff @(posedge clk_i) begin
    if (reset_i) begin
      state_r <= e_reset;
    end else begin
      state_r <= state_n;
    end
  end

endmodule
