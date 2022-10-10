/**
 *  Name:
 *    bp_lce.sv
 *
 *
 *  Description:
 *    Generic Local Cache/Coherence Engine (LCE).
 *
 *  TODO: resolve comments below regarding cache fill interface arbitration
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_lce
  import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // parameters specific to this LCE (these match the cache managed by the LCE)
   , parameter `BSG_INV_PARAM(assoc_p)
   , parameter `BSG_INV_PARAM(sets_p)
   , parameter `BSG_INV_PARAM(block_width_p)
   , parameter `BSG_INV_PARAM(fill_width_p)
   // number of LCE command buffer elements
   , parameter cmd_buffer_els_p = 2
   , parameter cmd_data_buffer_els_p = 2
   // number of LCE fill message buffer elements
   , parameter fill_buffer_els_p = 2
   , parameter fill_data_buffer_els_p = 2

   // LCE-cache interface timeout in cycles
   , parameter timeout_max_limit_p=4
   // maximum number of outstanding transactions
   , parameter credits_p = coh_noc_max_credits_p
   // issue non-exclusive read requests
   , parameter non_excl_reads_p = 0
   // latency of request metadata in cycles, must be 0 or 1
   // BP caches' metadata arrives cycle after request, by default
   , parameter metadata_latency_p = 1
  
	 // Cache tag width
   , localparam ctag_width_lp = caddr_width_p - (`BSG_SAFE_CLOG2(block_width_p*sets_p/8))

   `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_lp, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache)
  )
  (
    input                                            clk_i
    , input                                          reset_i

    // LCE Configuration
    , input [lce_id_width_p-1:0]                     lce_id_i
    , input bp_lce_mode_e                            lce_mode_i

    // Cache-LCE Interface
    // valid->yumi; metadata is valid only at metadata_latency_p cycles after request valid
    // metadata arrives in the same cycle as req, or any cycle after, but before the next request
    // can arrive, as indicated by the metadata_v_i signal
    , input [cache_req_width_lp-1:0]                 cache_req_i
    , input                                          cache_req_v_i
    , output logic                                   cache_req_yumi_o
    , output logic                                   cache_req_busy_o
    , input [cache_req_metadata_width_lp-1:0]        cache_req_metadata_i
    , input                                          cache_req_metadata_v_i
    , output logic                                   cache_req_critical_tag_o
    , output logic                                   cache_req_critical_data_o
    , output logic                                   cache_req_complete_o
    , output logic                                   cache_req_credits_full_o
    , output logic                                   cache_req_credits_empty_o

    // LCE-Cache Interface
    // valid->yumi
    // commands issued that read and return data have data returned the cycle after
    // the valid->yumi command handshake occurs
    , output logic                                   tag_mem_pkt_v_o
    , output logic [cache_tag_mem_pkt_width_lp-1:0]  tag_mem_pkt_o
    , input                                          tag_mem_pkt_yumi_i
    , input [cache_tag_info_width_lp-1:0]            tag_mem_i

    , output logic                                   data_mem_pkt_v_o
    , output logic [cache_data_mem_pkt_width_lp-1:0] data_mem_pkt_o
    , input                                          data_mem_pkt_yumi_i
    , input [block_width_p-1:0]                      data_mem_i

    , output logic                                   stat_mem_pkt_v_o
    , output logic [cache_stat_mem_pkt_width_lp-1:0] stat_mem_pkt_o
    , input                                          stat_mem_pkt_yumi_i
    , input [cache_stat_info_width_lp-1:0]           stat_mem_i

    // LCE-CCE Interface
    // BedRock Burst protocol: ready&valid
    , output logic [lce_req_header_width_lp-1:0]     lce_req_header_o
    , output logic                                   lce_req_header_v_o
    , input                                          lce_req_header_ready_and_i
    , output logic                                   lce_req_has_data_o
    , output logic [fill_width_p-1:0]                lce_req_data_o
    , output logic                                   lce_req_data_v_o
    , input                                          lce_req_data_ready_and_i
    , output logic                                   lce_req_last_o

    , input [lce_cmd_header_width_lp-1:0]            lce_cmd_header_i
    , input                                          lce_cmd_header_v_i
    , output logic                                   lce_cmd_header_ready_and_o
    , input                                          lce_cmd_has_data_i
    , input [fill_width_p-1:0]                       lce_cmd_data_i
    , input                                          lce_cmd_data_v_i
    , output logic                                   lce_cmd_data_ready_and_o
    , input                                          lce_cmd_last_i

    , input [lce_fill_header_width_lp-1:0]           lce_fill_header_i
    , input                                          lce_fill_header_v_i
    , output logic                                   lce_fill_header_ready_and_o
    , input                                          lce_fill_has_data_i
    , input [fill_width_p-1:0]                       lce_fill_data_i
    , input                                          lce_fill_data_v_i
    , output logic                                   lce_fill_data_ready_and_o
    , input                                          lce_fill_last_i

    , output logic [lce_fill_header_width_lp-1:0]    lce_fill_header_o
    , output logic                                   lce_fill_header_v_o
    , input                                          lce_fill_header_ready_and_i
    , output logic                                   lce_fill_has_data_o
    , output logic [fill_width_p-1:0]                lce_fill_data_o
    , output logic                                   lce_fill_data_v_o
    , input                                          lce_fill_data_ready_and_i
    , output logic                                   lce_fill_last_o

    , output logic [lce_resp_header_width_lp-1:0]    lce_resp_header_o
    , output logic                                   lce_resp_header_v_o
    , input                                          lce_resp_header_ready_and_i
    , output logic                                   lce_resp_has_data_o
    , output logic [fill_width_p-1:0]                lce_resp_data_o
    , output logic                                   lce_resp_data_v_o
    , input                                          lce_resp_data_ready_and_i
    , output logic                                   lce_resp_last_o
  );

  // LCE/Cache Parameter Constraints
  if ((sets_p <= 1) || !(`BSG_IS_POW2(sets_p)))
    $error("LCE sets must be greater than 1 and power of two");
  if (!(`BSG_IS_POW2(assoc_p)))
    $error("LCE assoc must be power of two");
  if (!(`BSG_IS_POW2(block_width_p)))
    $error("LCE block width must be a power of two");
  if (block_width_p < 64 || block_width_p > 1024)
    $error("LCE block width must be between 8 and 128 bytes");
  // cache request packet data width == dword_width_gp
  // LCE only supports single data beat for requests
  if (fill_width_p < dword_width_gp)
    $error("fill width must be greater or equal than cache request data width");
  if ((metadata_latency_p > 1))
    $error("metadata needs to arrive <2 cycles after the request");
  if (cmd_buffer_els_p < 1 || fill_buffer_els_p < 1)
    $error("LCEs require buffers for at least 1 command and fill header");
  if (cmd_data_buffer_els_p < 1 || fill_data_buffer_els_p < 1)
    $error("LCEs require buffers for at least 1 command and fill data beat");

  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_lp, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache);
  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);

  // LCE Request Module
  logic req_ready_lo;
  logic uc_store_req_complete_lo;
  logic sync_done_lo;
  logic cache_init_done_lo;
  bp_lce_req
   #(.bp_params_p(bp_params_p)
     ,.assoc_p(assoc_p)
     ,.sets_p(sets_p)
     ,.block_width_p(block_width_p)
     ,.fill_width_p(fill_width_p)
     ,.credits_p(credits_p)
     ,.non_excl_reads_p(non_excl_reads_p)
     ,.metadata_latency_p(metadata_latency_p)
     )
   request
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i(lce_id_i)
     ,.lce_mode_i(lce_mode_i)
     ,.sync_done_i(sync_done_lo)
     ,.cache_init_done_i(cache_init_done_lo)

     ,.ready_o(req_ready_lo)

     ,.cache_req_i(cache_req_i)
     ,.cache_req_v_i(cache_req_v_i)
     ,.cache_req_yumi_o(cache_req_yumi_o)
     ,.cache_req_metadata_i(cache_req_metadata_i)
     ,.cache_req_metadata_v_i(cache_req_metadata_v_i)
     ,.cache_req_complete_i(cache_req_complete_o)
     ,.credits_full_o(cache_req_credits_full_o)
     ,.credits_empty_o(cache_req_credits_empty_o)

     ,.uc_store_req_complete_i(uc_store_req_complete_lo)

     ,.lce_req_header_o(lce_req_header_o)
     ,.lce_req_header_v_o(lce_req_header_v_o)
     ,.lce_req_has_data_o(lce_req_has_data_o)
     ,.lce_req_header_ready_and_i(lce_req_header_ready_and_i)
     ,.lce_req_data_o(lce_req_data_o)
     ,.lce_req_data_v_o(lce_req_data_v_o)
     ,.lce_req_last_o(lce_req_last_o)
     ,.lce_req_data_ready_and_i(lce_req_data_ready_and_i)
     );

  // To prevent unnecessary arbitration on the critical cache request ports, we multiplex
  //   LCE cmds and LCE fills into a single stream at this point. This could be done for
  //   perhaps a bit less overhead at the netlist level, but it's more challenging to
  //   verify protocol/deadlock correctness at that level. At this level, we can simply
  //   say that it's sufficient to buffer a full output fill message such that it's never
  //   the case that an input cmd is blocked by an output fill 
  bp_bedrock_lce_cmd_header_s lce_cmd_header_li;
  logic [fill_width_p-1:0] lce_cmd_data_li;
  logic lce_cmd_header_v_li, lce_cmd_header_ready_and_lo;
  logic lce_cmd_data_v_li, lce_cmd_data_ready_and_lo;
  logic lce_cmd_has_data_li, lce_cmd_last_li;

  bp_me_xbar_burst
   #(.bp_params_p(bp_params_p)
     ,.data_width_p(fill_width_p)
     ,.payload_width_p(lce_cmd_payload_width_lp)
     ,.num_source_p(2)
     ,.num_sink_p(1)
     )
   lce_cmd_fill_xbar
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_i({lce_cmd_header_i, lce_fill_header_i})
     ,.msg_header_v_i({lce_cmd_header_v_i, lce_fill_header_v_i})
     ,.msg_header_ready_and_o({lce_cmd_header_ready_and_o, lce_fill_header_ready_and_o})
     ,.msg_has_data_i({lce_cmd_has_data_i, lce_fill_has_data_i})
     ,.msg_data_i({lce_cmd_data_i, lce_fill_data_i})
     ,.msg_data_v_i({lce_cmd_data_v_i, lce_fill_data_v_i})
     ,.msg_data_ready_and_o({lce_cmd_data_ready_and_o, lce_fill_data_ready_and_o})
     ,.msg_last_i({lce_cmd_last_i, lce_fill_last_i})
     ,.msg_dst_i('0) // Single destination

     ,.msg_header_o(lce_cmd_header_li)
     ,.msg_header_v_o(lce_cmd_header_v_li)
     ,.msg_header_ready_and_i(lce_cmd_header_ready_and_lo)
     ,.msg_has_data_o(lce_cmd_has_data_li)
     ,.msg_data_o(lce_cmd_data_li)
     ,.msg_data_v_o(lce_cmd_data_v_li)
     ,.msg_data_ready_and_i(lce_cmd_data_ready_and_lo)
     ,.msg_last_o(lce_cmd_last_li)
     );

  bp_bedrock_lce_fill_header_s lce_fill_header_lo;
  logic [fill_width_p-1:0] lce_fill_data_lo;
  logic lce_fill_header_v_lo, lce_fill_header_ready_and_li;
  logic lce_fill_data_v_lo, lce_fill_data_ready_and_li;
  logic lce_fill_has_data_lo, lce_fill_last_lo;
  bsg_two_fifo
   #(.width_p(1+$bits(bp_bedrock_lce_fill_header_s)))
   lce_fill_header_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({lce_fill_has_data_lo, lce_fill_header_lo})
     ,.v_i(lce_fill_header_v_lo)
     ,.ready_o(lce_fill_header_ready_and_li)

     ,.data_o({lce_fill_has_data_o, lce_fill_header_o})
     ,.v_o(lce_fill_header_v_o)
     ,.yumi_i(lce_fill_header_ready_and_i & lce_fill_header_v_o)
     );

  bsg_fifo_1r1w_small
   #(.width_p(1+fill_width_p), .els_p(block_width_p/fill_width_p))
   lce_fill_data_fifo
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.data_i({lce_fill_last_lo, lce_fill_data_lo})
     ,.v_i(lce_fill_data_v_lo)
     ,.ready_o(lce_fill_data_ready_and_li)

     ,.data_o({lce_fill_last_o, lce_fill_data_o})
     ,.v_o(lce_fill_data_v_o)
     ,.yumi_i(lce_fill_data_ready_and_i & lce_fill_data_v_o)
     );

  // LCE Command Module
  bp_lce_cmd
   #(.bp_params_p(bp_params_p)
     ,.assoc_p(assoc_p)
     ,.sets_p(sets_p)
     ,.block_width_p(block_width_p)
     ,.fill_width_p(fill_width_p)
     ,.cmd_buffer_els_p(cmd_buffer_els_p)
     ,.cmd_data_buffer_els_p(cmd_data_buffer_els_p)
     )
   command
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.lce_id_i(lce_id_i)
     ,.lce_mode_i(lce_mode_i)

     ,.cache_init_done_o(cache_init_done_lo)
     ,.sync_done_o(sync_done_lo)
     ,.cache_req_complete_o(cache_req_complete_o)
     ,.cache_req_critical_tag_o(cache_req_critical_tag_o)
     ,.cache_req_critical_data_o(cache_req_critical_data_o)
     ,.uc_store_req_complete_o(uc_store_req_complete_lo)

     ,.data_mem_pkt_o(data_mem_pkt_o)
     ,.data_mem_pkt_v_o(data_mem_pkt_v_o)
     ,.data_mem_pkt_yumi_i(data_mem_pkt_yumi_i)
     ,.data_mem_i(data_mem_i)

     ,.tag_mem_pkt_o(tag_mem_pkt_o)
     ,.tag_mem_pkt_v_o(tag_mem_pkt_v_o)
     ,.tag_mem_pkt_yumi_i(tag_mem_pkt_yumi_i)
     ,.tag_mem_i(tag_mem_i)

     ,.stat_mem_pkt_o(stat_mem_pkt_o)
     ,.stat_mem_pkt_v_o(stat_mem_pkt_v_o)
     ,.stat_mem_pkt_yumi_i(stat_mem_pkt_yumi_i)
     ,.stat_mem_i(stat_mem_i)

     ,.lce_cmd_header_i(lce_cmd_header_li)
     ,.lce_cmd_header_v_i(lce_cmd_header_v_li)
     ,.lce_cmd_has_data_i(lce_cmd_has_data_li)
     ,.lce_cmd_header_ready_and_o(lce_cmd_header_ready_and_lo)
     ,.lce_cmd_data_i(lce_cmd_data_li)
     ,.lce_cmd_data_v_i(lce_cmd_data_v_li)
     ,.lce_cmd_last_i(lce_cmd_last_li)
     ,.lce_cmd_data_ready_and_o(lce_cmd_data_ready_and_lo)

     ,.lce_fill_header_o(lce_fill_header_lo)
     ,.lce_fill_header_v_o(lce_fill_header_v_lo)
     ,.lce_fill_has_data_o(lce_fill_has_data_lo)
     ,.lce_fill_header_ready_and_i(lce_fill_header_ready_and_li)
     ,.lce_fill_data_o(lce_fill_data_lo)
     ,.lce_fill_data_v_o(lce_fill_data_v_lo)
     ,.lce_fill_last_o(lce_fill_last_lo)
     ,.lce_fill_data_ready_and_i(lce_fill_data_ready_and_li)

     ,.lce_resp_header_o(lce_resp_header_o)
     ,.lce_resp_header_v_o(lce_resp_header_v_o)
     ,.lce_resp_has_data_o(lce_resp_has_data_o)
     ,.lce_resp_header_ready_and_i(lce_resp_header_ready_and_i)
     ,.lce_resp_data_o(lce_resp_data_o)
     ,.lce_resp_data_v_o(lce_resp_data_v_o)
     ,.lce_resp_last_o(lce_resp_last_o)
     ,.lce_resp_data_ready_and_i(lce_resp_data_ready_and_i)
     );

  // LCE timeout logic
  //
  // LCE can read/write to data_mem, tag_mem, and stat_mem during cycles the cache itself is
  // not using them. To prevent the LCE from stalling for too long while waiting for one of
  // these ports, or when processing an inbound LCE command, there is a timer that raises the
  // LCE's busy_o signal to prevent the cache from issuing a new request, thereby
  // freeing up a cycle for the LCE to use these resources.

  logic [`BSG_SAFE_CLOG2(timeout_max_limit_p+1)-1:0] timeout_cnt_r;
  wire coherence_blocked =
    (data_mem_pkt_v_o & ~data_mem_pkt_yumi_i)
    | (tag_mem_pkt_v_o & ~tag_mem_pkt_yumi_i)
    | (stat_mem_pkt_v_o & ~stat_mem_pkt_yumi_i);

  bsg_counter_clear_up
   #(.max_val_p(timeout_max_limit_p)
     ,.init_val_p(0)
     ,.disable_overflow_warning_p(1)
     )
   timeout_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.clear_i(~coherence_blocked)
     ,.up_i(coherence_blocked)
     ,.count_o(timeout_cnt_r)
     );
  wire timeout = (timeout_cnt_r == timeout_max_limit_p);

  // LCE is ready to accept new cache requests if:
  // - LCE Request module is ready to accept a request (does not account for a free credit)
  // - timout signal is low, indicating LCE isn't blocked on using data/tag/stat mem
  // This signal acts as a hint to the cache that the LCE is not ready for a request.
  // The cache_req_yumi_o signal actually controls whether the LCE accepts a request.
  assign cache_req_busy_o = timeout | ~req_ready_lo;

endmodule

`BSG_ABSTRACT_MODULE(bp_lce)
