/**
 *
 * Name:
 *   bp_cce_hybrid_req.sv
 *
 * Description:
 *   This module processes new LCE requests and splits them into cacheable memory and uncacheable
 *   memory streams. Accesses to uncacheable memory (which must be uncached acceses) bypass the
 *   bulk of the CCE pipeline and are not blocked by the coherence protocol.
 *
 *   LCE Request headers are buffered to enable routing and arbitration of requests between
 *   the two channels without violating the ready&valid handshaking. Data is not buffered and is
 *   processed in the cycle following the header being sent to one of the outputs.
 *
 *   The CCE operates in two modes: uncached only or normal. In normal mode, requests to cacheable
 *   memory participate in the cache coherence protocol. In uncached only all requests are routed to
 *   the uncached pipeline. The cce_mode_i signal provides the current operating mode, which will
 *   only be switched when this module is empty (i.e., safety is provided by the CCE control module).
 *
 *   The CCE may transition modes at any time. This transition is indicated by the CCE control
 *   module raising the stall_i wire, which causes this module to drain its current requests.
 *   The empty_o signal is raised whenever there are no valid requests in this modules header
 *   and data control fifos.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_cce_hybrid_req
  import bp_common_pkg::*;
  import bp_me_pkg::*;
  #(parameter bp_params_e bp_params_p = e_bp_default_cfg
    `declare_bp_proc_params(bp_params_p)

    , parameter buffer_els_p = 2

    // interface width
    `declare_bp_bedrock_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p)
  )
  (input                                            clk_i
   , input                                          reset_i

   // control
   , input bp_cce_mode_e                            cce_mode_i
   , input                                          stall_i
   , output logic                                   empty_o

   // LCE Request
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input [bedrock_fill_width_p-1:0]               lce_req_data_i
   , input                                          lce_req_v_i
   , output logic                                   lce_req_ready_and_o

   // Uncached or Cached to cacheable memory
   , output logic [lce_req_header_width_lp-1:0]     lce_req_header_o
   , output logic [bedrock_fill_width_p-1:0]        lce_req_data_o
   , output logic                                   lce_req_v_o
   , input                                          lce_req_ready_and_i

   // Uncached to uncacheable memory
   , output logic [lce_req_header_width_lp-1:0]     uc_lce_req_header_o
   , output logic [bedrock_fill_width_p-1:0]        uc_lce_req_data_o
   , output logic                                   uc_lce_req_v_o
   , input                                          uc_lce_req_ready_and_i
   );

  // Define structure variables for output queues
  `declare_bp_bedrock_if(paddr_width_p, lce_id_width_p, cce_id_width_p, did_width_p, lce_assoc_p);

  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_o(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_o(bp_bedrock_lce_req_header_s, uc_lce_req_header);

  // LCE Request Buffer
  // Required to properly handle cacheable/uncacheable arbitration
  logic lce_req_v_li, lce_req_yumi_lo;
  logic lce_req_ready_and_lo;
  bp_bedrock_lce_req_header_s lce_req_header_li;
  logic [bedrock_fill_width_p-1:0] lce_req_data_li;
  wire lce_req_v_wire = lce_req_v_i & ~stall_i;
  bsg_fifo_1r1w_small
    #(.width_p(lce_req_header_width_lp+bedrock_fill_width_p)
      ,.els_p(buffer_els_p)
      ,.ready_THEN_valid_p(0)
      )
    lce_req_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // input
      // stall signal blocks new headers from entering fifo
      ,.v_i(lce_req_v_wire)
      ,.ready_param_o(lce_req_ready_and_lo)
      ,.data_i({lce_req_data_i, lce_req_header_cast_i})
      // output
      ,.v_o(lce_req_v_li)
      ,.yumi_i(lce_req_yumi_lo)
      ,.data_o({lce_req_data_li, lce_req_header_li})
      );
  // stall signal blocks new headers from entering fifo
  assign lce_req_ready_and_o = ~stall_i & lce_req_ready_and_lo;

  // Check cacheable memory access of LCE request
  logic cacheable_req_li;
  bp_cce_pma
    #(.bp_params_p(bp_params_p)
      )
    req_pma
      (.paddr_i(lce_req_header_li.addr)
       ,.cacheable_addr_o(cacheable_req_li)
       );
  // only cacheable if cacheable mode enabled
  wire cce_normal_mode = (cce_mode_i == e_cce_mode_normal);
  wire cacheable_req = cacheable_req_li & cce_normal_mode;

  // Combinational Logic
  always_comb begin
    //  module empty after draining header and data control fifos
    empty_o = ~lce_req_v_li;

    // cacheable/coherent request out
    lce_req_header_cast_o = lce_req_header_li;
    lce_req_data_o = lce_req_data_li;

    // uncacheable request out
    uc_lce_req_header_cast_o = lce_req_header_li;
    uc_lce_req_data_o = lce_req_data_li;

    // arbitration
    lce_req_v_o = lce_req_v_li & cacheable_req;
    uc_lce_req_v_o = lce_req_v_li & ~cacheable_req;
    lce_req_yumi_lo = (lce_req_v_o & lce_req_ready_and_i) | (uc_lce_req_v_o & uc_lce_req_ready_and_i);
  end

  //synopsys translate_off
  always @(negedge clk_i) begin
    if (~reset_i) begin
      // Cacheable requests must target cacheable memory
      assert(~lce_req_v_li
             || (lce_req_header_li.msg_type.req inside {e_bedrock_req_rd_miss, e_bedrock_req_wr_miss}
                 && cacheable_req_li)
             || !(lce_req_header_li.msg_type.req inside {e_bedrock_req_rd_miss, e_bedrock_req_wr_miss}))
        else $error("CCE PMA violation - cacheable requests must target cacheable memory");
      // Cacheable requests require normal mode
      // TODO: should CCE automatically convert cacheable to uncacheable when in uncached only
      // mode? uc_pipe does this
      assert(!(lce_req_v_li && cacheable_req_li & ~cce_normal_mode)) else
        $warning("CCE cacheable request but cacheable mode not enabled");
    end
  end
  //synopsys translate_on


endmodule
