/**
 *  Name:
 *    bp_lce_req.sv
 *
 *  Description:
 *    LCE request handler.
 *
 *    Issues LCE requests when cache misses arrive. Supports cached, uncached, and uncached atomic
 *    requests.
 *
 */

`include "bp_common_defines.svh"
`include "bp_me_defines.svh"

module bp_lce_req
  import bp_common_pkg::*;
 #(parameter bp_params_e bp_params_p = e_bp_default_cfg
   `declare_bp_proc_params(bp_params_p)

   // parameters specific to this LCE (these match the cache managed by the LCE)
   , parameter `BSG_INV_PARAM(assoc_p)
   , parameter `BSG_INV_PARAM(sets_p)
   , parameter `BSG_INV_PARAM(block_width_p)
   , parameter `BSG_INV_PARAM(fill_width_p)
   , parameter `BSG_INV_PARAM(ctag_width_p)

   // LCE-cache interface timeout in cycles
   , parameter timeout_max_limit_p=4
   // maximum number of outstanding transactions
   , parameter credits_p = coh_noc_max_credits_p
   // issue non-exclusive read requests
   , parameter non_excl_reads_p = 0
   // latency of request metadata in cycles, must be 0 or 1
   // BP caches' metadata arrives cycle after request, by default
   , parameter metadata_latency_p = 1

   // byte offset bits required per bedrock data channel beat
   , localparam bedrock_byte_offset_lp = `BSG_SAFE_CLOG2(fill_width_p/8)
   , localparam bit [paddr_width_p-1:0] req_addr_mask = {paddr_width_p{1'b1}} << bedrock_byte_offset_lp

   `declare_bp_bedrock_lce_if_widths(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p)
   `declare_bp_cache_engine_if_widths(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache)
  )
  (
    input                                            clk_i
    , input                                          reset_i

    // LCE Configuration
    , input [lce_id_width_p-1:0]                     lce_id_i
    , input bp_lce_mode_e                            lce_mode_i
    , input                                          cache_init_done_i
    , input                                          sync_done_i

    // LCE Req is not able to accept requests
    , output logic                                   busy_o

    // Cache-LCE Interface
    // ready / valid handshake
    // metadata arrives in the same cycle as req, or any cycle after, but before the next request
    // can arrive, as indicated by the metadata_v_i signal
    , input [cache_req_width_lp-1:0]                 cache_req_i
    , input                                          cache_req_v_i
    , output logic                                   cache_req_yumi_o
    , input [cache_req_metadata_width_lp-1:0]        cache_req_metadata_i
    , input                                          cache_req_metadata_v_i

    // LCE-Cache Interface
    , output logic                                   credits_full_o
    , output logic                                   credits_empty_o

    // LCE Cmd - LCE Req Interface
    // request complete signal from LCE Cmd module - Cached Load/Store and Uncached Load
    // this signal is raised exactly once, for a single cycle, per request completing, and it
    // can be raised at any time after the LCE request sends out
    , input                                          credit_return_i
    , input                                          cache_req_done_i
    , output logic                                   backoff_o

    // LCE-CCE Interface
    // BedRock Burst protocol: ready&valid
    , output logic [lce_req_header_width_lp-1:0]     lce_req_header_o
    , output logic [bedrock_fill_width_p-1:0]        lce_req_data_o
    , output logic                                   lce_req_v_o
    , input                                          lce_req_ready_and_i
  );

  `declare_bp_bedrock_lce_if(paddr_width_p, lce_id_width_p, cce_id_width_p, lce_assoc_p);
  `declare_bp_cache_engine_if(paddr_width_p, ctag_width_p, sets_p, assoc_p, dword_width_gp, block_width_p, fill_width_p, cache);
  `bp_cast_o(bp_bedrock_lce_req_header_s, lce_req_header);
  `bp_cast_i(bp_cache_req_s, cache_req);

  // cache request valid and register
  // set over clear because new request can be captured same cycle existing request sends
  // cache_req_v_r indicates if a valid request is in the buffer
  logic cache_req_v_r, nonblocking_req_sent, blocking_req_sent;
  bsg_dff_reset_set_clear
   #(.width_p(1))
   cache_req_v_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.set_i(cache_req_yumi_o & cache_req_v_i)
     ,.clear_i(cache_req_done_i | nonblocking_req_sent)
     ,.data_o(cache_req_v_r)
     );

  enum logic [1:0] {e_reset, e_ready, e_request} state_n, state_r;
  wire is_reset   = (state_r == e_reset);
  wire is_ready   = (state_r == e_ready);
  wire is_request = (state_r == e_request);

  bp_cache_req_s cache_req_r;
  bsg_dff_en
   #(.width_p($bits(bp_cache_req_s)))
   req_reg
    (.clk_i(clk_i)
     ,.en_i(cache_req_yumi_o & cache_req_v_i)
     ,.data_i(cache_req_i)
     ,.data_o(cache_req_r)
     );

  bp_cache_req_metadata_s cache_req_metadata_r;
  bsg_dff_reset_en_bypass
   #(.width_p($bits(bp_cache_req_metadata_s)))
   metadata_reg
    (.clk_i(clk_i)
     ,.reset_i(reset_i)
     ,.en_i(cache_req_metadata_v_i)
     ,.data_i(cache_req_metadata_i)
     ,.data_o(cache_req_metadata_r)
     );

  bp_bedrock_lce_req_header_s fsm_req_header_lo;
  logic [paddr_width_p-1:0] fsm_req_addr_lo;
  logic [fill_width_p-1:0] fsm_req_data_lo;
  logic fsm_req_v_lo, fsm_req_ready_and_li;
  logic fsm_req_new_lo, fsm_req_critical_lo, fsm_req_last_lo;
  bp_me_stream_pump_out
   #(.bp_params_p(bp_params_p)
     ,.fsm_data_width_p(fill_width_p)
     ,.block_width_p(block_width_p)
     ,.payload_width_p(lce_req_payload_width_lp)
     ,.msg_stream_mask_p(lce_req_stream_mask_gp)
     ,.fsm_stream_mask_p(lce_req_stream_mask_gp)
     )
   lce_req_pump_out
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.msg_header_o(lce_req_header_cast_o)
     ,.msg_data_o(lce_req_data_o)
     ,.msg_v_o(lce_req_v_o)
     ,.msg_ready_and_i(lce_req_ready_and_i)

     ,.fsm_header_i(fsm_req_header_lo)
     ,.fsm_addr_o(fsm_req_addr_lo)
     ,.fsm_data_i(fsm_req_data_lo)
     ,.fsm_v_i(fsm_req_v_lo)
     ,.fsm_ready_and_o(fsm_req_ready_and_li)
     ,.fsm_new_o(fsm_req_new_lo)
     ,.fsm_critical_o(fsm_req_critical_lo)
     ,.fsm_last_o(fsm_req_last_lo)
     );

  wire miss_load_v_r  = cache_req_v_r & cache_req_r.msg_type inside {e_miss_load};
  wire miss_store_v_r = cache_req_v_r & cache_req_r.msg_type inside {e_miss_store};
  wire miss_v_r       = cache_req_v_r & miss_load_v_r | miss_store_v_r;
  wire uc_load_v_r    = cache_req_v_r & cache_req_r.msg_type inside {e_uc_load};
  wire uc_amo_v_r     = cache_req_v_r & cache_req_r.msg_type inside {e_uc_amo};
  wire backoff_v_r    = cache_req_v_r & cache_req_r.msg_type inside {e_cache_backoff};
  wire uc_store_v_r   = cache_req_v_r & cache_req_r.msg_type inside {e_uc_store};

  // Outstanding request credit counter
  // one credit used per LCE request sent
  logic [`BSG_WIDTH(credits_p)-1:0] credit_count_lo;
  wire credit_v_li = fsm_req_v_lo & fsm_req_new_lo;
  wire credit_ready_li = fsm_req_ready_and_li;
  wire credit_returned_li = credit_return_i;
  bsg_flow_counter
    #(.els_p(credits_p))
    req_counter
      (.clk_i(clk_i)
      ,.reset_i(reset_i)
      ,.v_i(credit_v_li)
      ,.ready_i(credit_ready_li)
      ,.yumi_i(credit_returned_li)
      ,.count_o(credit_count_lo)
      );
  assign credits_full_o  =  cache_req_v_r && (credit_count_lo == credits_p);
  assign credits_empty_o = ~cache_req_v_r && (credit_count_lo == '0);

  // Linear backoff
  localparam lock_max_limit_lp = 7;
  logic [`BSG_SAFE_CLOG2(lock_max_limit_lp+1)-1:0] lock_cnt_r;
  wire lock_inc = backoff_v_r || (lock_cnt_r > '0);
  bsg_counter_clear_up
   #(.max_val_p(lock_max_limit_lp), .init_val_p(0), .disable_overflow_warning_p(1))
   lock_counter
    (.clk_i(clk_i)
     ,.reset_i(reset_i)

     ,.clear_i('0)
     ,.up_i(lock_inc)
     ,.count_o(lock_cnt_r)
     );
  assign backoff_o = (lock_cnt_r != '0);

  // Request Address to CCE
  logic [cce_id_width_p-1:0] req_cce_id_lo;
  bp_me_addr_to_cce_id
   #(.bp_params_p(bp_params_p))
   req_map
    (.paddr_i(cache_req_r.addr)
     ,.cce_id_o(req_cce_id_lo)
     );

  // LCE should suppress messages if in reset or we are not synchronized with the CCE
  // busy being lowered does not guarantee that this module will accept a valid cache request
  // packet (refer to cache_req_yumi_o below).
  assign busy_o = ~sync_done_i && (lce_mode_i == e_lce_mode_normal);

  // atomic request subop determination
  bp_bedrock_wr_subop_e req_subop;
  always_comb
    unique case (cache_req_r.subop)
      e_req_amolr  : req_subop = e_bedrock_amolr;
      e_req_amosc  : req_subop = e_bedrock_amosc;
      e_req_amoswap: req_subop = e_bedrock_amoswap;
      e_req_amoadd : req_subop = e_bedrock_amoadd;
      e_req_amoxor : req_subop = e_bedrock_amoxor;
      e_req_amoand : req_subop = e_bedrock_amoand;
      e_req_amoor  : req_subop = e_bedrock_amoor;
      e_req_amomin : req_subop = e_bedrock_amomin;
      e_req_amomax : req_subop = e_bedrock_amomax;
      e_req_amominu: req_subop = e_bedrock_amominu;
      e_req_amomaxu: req_subop = e_bedrock_amomaxu;
      default : req_subop = e_bedrock_store;
    endcase

  always_comb begin
    // Request message defaults
    fsm_req_header_lo = '0;
    fsm_req_header_lo.addr = cache_req_r.addr;
    fsm_req_header_lo.size = bp_bedrock_msg_size_e'(cache_req_r.size);
    fsm_req_header_lo.payload.dst_id = req_cce_id_lo;
    fsm_req_header_lo.payload.src_id = lce_id_i;
    fsm_req_header_lo.payload.lru_way_id = lce_assoc_width_p'(cache_req_metadata_r.hit_or_repl_way);
    fsm_req_header_lo.payload.non_exclusive =
      (miss_load_v_r && (non_excl_reads_p == 1)) ? e_bedrock_req_non_excl : e_bedrock_req_excl;
    fsm_req_header_lo.subop = req_subop;
    fsm_req_data_lo = cache_req_r.data;

    // Send request header when able
    // requires valid cache request and possibly valid metadata (cached requests only)
    unique case (cache_req_r.msg_type)
      e_uc_store  : fsm_req_header_lo.msg_type.req = e_bedrock_req_uc_wr;
      e_uc_load   : fsm_req_header_lo.msg_type.req = e_bedrock_req_uc_rd;
      e_uc_amo    : fsm_req_header_lo.msg_type.req = e_bedrock_req_uc_amo;
      e_miss_load : fsm_req_header_lo.msg_type.req = e_bedrock_req_rd_miss;
      e_miss_store: fsm_req_header_lo.msg_type.req = e_bedrock_req_wr_miss;
      default: begin end
    endcase

    // Send out in ready state only
    fsm_req_v_lo = is_ready & cache_req_v_r & ~backoff_v_r & (credit_count_lo < credits_p);

    // request finishes sending when last data sends (single beat supported only)
    nonblocking_req_sent = backoff_v_r | (uc_store_v_r & fsm_req_ready_and_li & fsm_req_v_lo);
    blocking_req_sent = (miss_v_r | uc_load_v_r | uc_amo_v_r) & fsm_req_ready_and_li & fsm_req_v_lo;
 
    cache_req_yumi_o = cache_req_v_i & (~cache_req_v_r | blocking_req_sent | blocking_req_sent);
  end

  always_comb
    case (state_r)
      e_ready  : state_n = blocking_req_sent ? e_request : state_r;
      e_request: state_n = cache_req_done_i ? e_ready : state_r;
      // e_reset:
      default  : state_n = cache_init_done_i ? e_ready : state_r;
    endcase

  // synopsys sync_set_reset "reset_i"
  always_ff @ (posedge clk_i)
    if (reset_i)
      state_r <= e_reset;
    else
      state_r <= state_n;

endmodule

`BSG_ABSTRACT_MODULE(bp_lce_req)

