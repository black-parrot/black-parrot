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

    , parameter lce_data_width_p = dword_width_gp
    // TODO: evaluate proper sizing of data control fifo
    // A larger data control fifo may allow higher sustained throughput of requests when many
    // requests arrive close in time but only a small fraction have data attached
    , parameter header_fifo_els_p = 2
    , parameter data_ctrl_els_p = header_fifo_els_p

    // interface widths
    `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce)
  )
  (input                                            clk_i
   , input                                          reset_i

   // control
   , input bp_cce_mode_e                            cce_mode_i
   , input                                          stall_i
   , output logic                                   empty_o

   // LCE Request
   // BedRock Burst protocol: ready&valid
   , input [lce_req_header_width_lp-1:0]            lce_req_header_i
   , input                                          lce_req_header_v_i
   , output logic                                   lce_req_header_ready_and_o
   , input                                          lce_req_has_data_i
   , input [lce_data_width_p-1:0]                   lce_req_data_i
   , input                                          lce_req_data_v_i
   , output logic                                   lce_req_data_ready_and_o
   , input                                          lce_req_last_i

   // Uncached or Cached to cacheable memory
   , output logic [lce_req_header_width_lp-1:0]     lce_req_header_o
   , output logic                                   lce_req_header_v_o
   , input                                          lce_req_header_ready_and_i
   , output logic                                   lce_req_has_data_o
   , output logic [lce_data_width_p-1:0]            lce_req_data_o
   , output logic                                   lce_req_data_v_o
   , input                                          lce_req_data_ready_and_i
   , output logic                                   lce_req_last_o

   // Uncached to uncacheable memory
   , output logic [lce_req_header_width_lp-1:0]     uc_lce_req_header_o
   , output logic                                   uc_lce_req_header_v_o
   , input                                          uc_lce_req_header_ready_and_i
   , output logic                                   uc_lce_req_has_data_o
   , output logic [lce_data_width_p-1:0]            uc_lce_req_data_o
   , output logic                                   uc_lce_req_data_v_o
   , input                                          uc_lce_req_data_ready_and_i
   , output logic                                   uc_lce_req_last_o
   );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p, lce);

  `bp_cast_i(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_o(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_o(bp_bedrock_lce_req_header_s, uc_lce_req_header);

  // LCE Request Header Buffer
  // Required to properly handle cacheable/uncacheable arbitration
  logic lce_req_header_v_li, lce_req_header_yumi_lo, lce_req_has_data_li;
  logic lce_req_header_ready_and_lo;
  bp_bedrock_lce_req_header_s  lce_req_header_li;
  bsg_fifo_1r1w_small
    #(.width_p(lce_req_header_width_lp+1)
      ,.els_p(header_fifo_els_p)
      )
    header_buffer
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // input
      // stall signal blocks new headers from entering fifo
      ,.v_i(lce_req_header_v_i & ~stall_i)
      ,.ready_o(lce_req_header_ready_and_lo)
      ,.data_i({lce_req_has_data_i, lce_req_header_cast_i})
      // output
      ,.v_o(lce_req_header_v_li)
      ,.yumi_i(lce_req_header_yumi_lo)
      ,.data_o({lce_req_has_data_li, lce_req_header_li})
      );
  // stall signal blocks new headers from entering fifo
  assign lce_req_header_ready_and_o = ~stall_i & lce_req_header_ready_and_lo;

  // Check cacheable memory access of LCE request
  logic cacheable_req_li;
  bp_cce_pma
    #(.bp_params_p(bp_params_p)
      )
    req_pma
      (.paddr_i(lce_req_header_li.addr)
       ,.paddr_v_i(lce_req_header_v_li)
       ,.cacheable_addr_o(cacheable_req_li)
       );
  // only cacheable if cacheable mode enabled
  wire cce_normal_mode = (cce_mode_i == e_cce_mode_normal);
  wire cacheable_req = cacheable_req_li & cce_normal_mode;

  // Data FSM
  typedef struct packed
  {
    logic has_data;
    logic cacheable;
  } data_ctrl_s;
  data_ctrl_s data_ctrl_li, data_ctrl_lo;

  logic data_ctrl_v_li, data_ctrl_ready_then_lo, data_ctrl_v_lo, data_ctrl_yumi_li;
  bsg_fifo_1r1w_small
    #(.width_p($bits(data_ctrl_s))
      ,.els_p(data_ctrl_els_p)
      ,.ready_THEN_valid_p(1)
      )
    data_ctrl_fifo
     (.clk_i(clk_i)
      ,.reset_i(reset_i)
      // input - ready-then-valid
      ,.v_i(data_ctrl_v_li)
      ,.ready_o(data_ctrl_ready_then_lo)
      ,.data_i(data_ctrl_li)
      // output
      ,.v_o(data_ctrl_v_lo)
      ,.yumi_i(data_ctrl_yumi_li)
      ,.data_o(data_ctrl_lo)
      );

  wire last_data_sent = lce_req_data_v_i & lce_req_data_ready_and_o & lce_req_last_i;

  // Combinational Logic
  always_comb begin
    //  module empty after draining header and data control fifos
    empty_o = ~data_ctrl_v_lo & ~lce_req_header_v_li;

    data_ctrl_li.has_data = lce_req_header_v_li & lce_req_has_data_li;
    data_ctrl_li.cacheable = cacheable_req;

    // Header routing
    // input request - header from buffer
    lce_req_header_yumi_lo = '0;
    // cacheable request out
    lce_req_header_cast_o = lce_req_header_li;
    lce_req_header_v_o = '0;
    lce_req_has_data_o = lce_req_header_v_li & lce_req_has_data_li;
    // uncacheable request out
    uc_lce_req_header_cast_o = lce_req_header_li;
    uc_lce_req_header_v_o = '0;
    uc_lce_req_has_data_o = lce_req_header_v_li & lce_req_has_data_li;

    // distribute header to cacheable or uncacheable output
    // space must also be available in data control fifo
    lce_req_header_v_o = lce_req_header_v_li & cacheable_req & data_ctrl_ready_then_lo;
    uc_lce_req_header_v_o = lce_req_header_v_li & ~cacheable_req & data_ctrl_ready_then_lo;
    // consume request header from buffer
    lce_req_header_yumi_lo = (lce_req_header_v_o & lce_req_header_ready_and_i)
                             | (uc_lce_req_header_v_o & uc_lce_req_header_ready_and_i);

    // Data control fifo is ready->valid. Enqueue when header sends (depends on ready_then)
    data_ctrl_v_li = lce_req_header_yumi_lo;

    // Data routing
    // cacheable request out
    lce_req_data_o = lce_req_data_i;
    lce_req_last_o = lce_req_last_i;
    // uncacheable request out
    uc_lce_req_data_o = lce_req_data_i;
    uc_lce_req_last_o = lce_req_last_i;

    // route data valid to cacheable or uncacheable output
    // only output if control packet indicates message has data
    lce_req_data_v_o = lce_req_data_v_i & data_ctrl_v_lo & data_ctrl_lo.has_data & data_ctrl_lo.cacheable;
    uc_lce_req_data_v_o = lce_req_data_v_i & data_ctrl_v_lo & data_ctrl_lo.has_data & ~data_ctrl_lo.cacheable;
    // route data ready signal based on cacheability register
    lce_req_data_ready_and_o = data_ctrl_v_lo & data_ctrl_lo.has_data
      & (data_ctrl_lo.cacheable
         ? lce_req_data_ready_and_i
         : uc_lce_req_data_ready_and_i
         );

    // data control
    // consume if:
    // 1. no data
    // 2. last data packet sends
    data_ctrl_yumi_li = data_ctrl_v_lo & (~data_ctrl_lo.has_data | last_data_sent);
  end

  //synopsys translate_off
  always @(negedge clk_i) begin
    if (~reset_i) begin
      // Cacheable requests must target cacheable memory
      assert(~lce_req_header_v_li
             || (lce_req_header_li.msg_type.req inside {e_bedrock_req_rd_miss, e_bedrock_req_wr_miss}
                 && cacheable_req_li)
             || !(lce_req_header_li.msg_type.req inside {e_bedrock_req_rd_miss, e_bedrock_req_wr_miss}))
        else $error("CCE PMA violation - cacheable requests must target cacheable memory");
      // Cacheable requests require normal mode
      // TODO: should CCE automatically convert cacheable to uncacheable when in uncached only
      // mode? uc_pipe does this
      assert(!(lce_req_header_v_li && cacheable_req_li & ~cce_normal_mode)) else
        $warning("CCE cacheable request but cacheable mode not enabled");
    end
  end
  //synopsys translate_on


endmodule
